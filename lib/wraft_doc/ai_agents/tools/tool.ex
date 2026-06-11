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

      def run(
            %{
              model: %{auth_key: auth_key} = model,
              prompt: %{prompt: prompt_text},
              content: content
            } = params,
            _context
          ) do
        start_time = System.monotonic_time(:millisecond)

        with {:ok, spec} <- ModelSpec.build(model),
             {:ok, llm_model} <- to_llm_model(spec) do
          messages = [
            ReqLLM.Context.system("You are an expert document summarizer and converter."),
            ReqLLM.Context.user("#{prompt_text}\n\nDocument content:\n#{content}")
          ]

          base_url = llm_model.base_url || to_string(llm_model.provider)
          opts = [api_key: auth_key] ++ structured_output_opts(llm_model)

          llm_model
          |> generate_with_retry(messages, opts, @max_attempts)
          |> case do
            {:ok, response} ->
              Models.create_model_log(params, "success", base_url, start_time)

              result =
                response
                |> ReqLLM.Response.object()
                |> then(&Ecto.embedded_load(@response_model, &1, :json))

              {:ok, result}

            {:error, reason} ->
              Models.create_model_log(params, "failed", base_url, start_time)
              AiAgents.format_error(reason)
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

      defp generate_with_retry(llm_model, messages, opts, attempts) do
        case ReqLLM.generate_object(llm_model, messages, @response_model.llm_schema(), opts) do
          {:ok, _response} = ok ->
            ok

          {:error, _reason} when attempts > 1 ->
            generate_with_retry(llm_model, messages, opts, attempts - 1)

          error ->
            error
        end
      end
    end
  end
end
