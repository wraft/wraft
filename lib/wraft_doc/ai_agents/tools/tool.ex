defmodule WraftDoc.AiAgents.Tool do
  @moduledoc """
  Base module for defining AI tools.
  """

  defmacro __using__(opts) do
    quote do
      use Jido.Action,
        name: unquote(opts[:name]),
        description: unquote(opts[:description]),
        schema: [
          prompt: [
            type: :string,
            required: true,
            doc: "Instructions for how to structure the doc"
          ],
          markdown: [type: :string, required: true, doc: "The markdown text content to process"]
        ]

      alias WraftDoc.AiAgents
      alias WraftDoc.AiAgents.ModelSpec
      alias WraftDoc.Models

      @response_model unquote(opts[:response_model])
      @max_attempts 3
      # Absolute wall-clock budget for the whole retry loop. The request process
      # blocks during backoff, so cap total time well under the frontend axios
      # timeout (120s) — a new attempt is not started once the next backoff
      # would push past this deadline.
      @max_total_ms 90_000

      def run(
            %{
              model: %{auth_key: auth_key} = model,
              prompt: %{prompt: prompt_text},
              content: content
            } = params,
            _context
          ) do
        start_time = System.monotonic_time(:millisecond)
        deadline = start_time + @max_total_ms

        with {:ok, spec} <- ModelSpec.build(model),
             {:ok, llm_model} <- to_llm_model(spec) do
          messages = [
            ReqLLM.Context.system("You are an expert document summarizer and converter."),
            ReqLLM.Context.user("#{prompt_text}\n\nDocument content:\n#{content}")
          ]

          base_url = llm_model.base_url || to_string(llm_model.provider)
          opts = [api_key: auth_key] ++ structured_output_opts(llm_model)

          llm_model
          |> generate_with_retry(messages, opts, @max_attempts, deadline)
          |> load_result()
          |> case do
            {:ok, result} ->
              Models.create_model_log(params, "success", base_url, start_time)
              {:ok, result}

            {:error, %{__exception__: true} = reason} ->
              Models.create_model_log(params, "failed", base_url, start_time)
              AiAgents.format_error(reason)

            {:error, reason} ->
              Models.create_model_log(params, "failed", base_url, start_time)
              {:error, reason}
          end
        else
          {:error, %{__exception__: true} = error} -> AiAgents.format_error(error)
          {:error, _reason} = error -> error
        end
      end

      defp to_llm_model(spec), do: ReqLLM.model(spec)

      # OpenAI-compatible servers (llama.cpp) support response_format
      # json_schema but not strict tool calling, which ReqLLM's :auto mode
      # falls back to for models missing from its registry.
      defp structured_output_opts(%{provider: :openai}),
        do: [openai_structured_output_mode: :json_schema]

      defp structured_output_opts(_llm_model), do: []

      defp generate_with_retry(llm_model, messages, opts, attempts, deadline) do
        case ReqLLM.generate_object(llm_model, messages, @response_model.llm_schema(), opts) do
          {:ok, _response} = ok ->
            ok

          {:error, reason} = error when attempts > 1 ->
            backoff = retry_backoff_ms(attempts)

            if retryable_error?(reason) and
                 System.monotonic_time(:millisecond) + backoff < deadline do
              Process.sleep(backoff)
              generate_with_retry(llm_model, messages, opts, attempts - 1, deadline)
            else
              error
            end

          error ->
            error
        end
      end

      defp retryable_error?(%{status: status}) when is_integer(status),
        do: status == 429 or status >= 500

      defp retryable_error?(_reason), do: false

      defp retry_backoff_ms(attempts) do
        exponent = @max_attempts - attempts
        trunc(:math.pow(2, exponent) * 500) + :rand.uniform(250)
      end

      defp load_result({:error, _reason} = error), do: error

      defp load_result({:ok, response}) do
        case ReqLLM.Response.object(response) do
          object when is_map(object) ->
            try do
              result = Ecto.embedded_load(@response_model, object, :json)

              if Enum.any?(@response_model.__schema__(:embeds), &is_nil(Map.get(result, &1))) do
                {:error, "The AI model returned an incomplete response, please try again"}
              else
                {:ok, result}
              end
            rescue
              _e in [ArgumentError, Ecto.CastError] ->
                {:error, "The AI model returned an unreadable response, please try again"}
            end

          _no_object ->
            {:error, "The AI model returned an unreadable response, please try again"}
        end
      end
    end
  end
end
