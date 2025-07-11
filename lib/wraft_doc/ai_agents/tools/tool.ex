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
      alias WraftDoc.Models

      @response_model unquote(opts[:response_model])

      def run(
            %{
              model: %{model_name: model_name, provider: provider, auth_key: auth_key} = model,
              prompt: %{prompt: prompt_text},
              content: content
            } = params,
            _context
          ) do
        start_time = System.monotonic_time(:millisecond)

        prompt =
          Jido.AI.Prompt.new(%{
            messages: [
              %{role: :system, content: "You are an expert document summarizer and converter."},
              %{role: :user, content: "#{prompt_text}\n\nDocument content:\n#{content}"}
            ]
          })

        model_config = [
          model: model_name,
          api_key: auth_key
        ]

        model_config =
          model
          |> Map.get(:endpoint_url)
          |> case do
            nil -> model_config
            endpoint_url -> model_config ++ [base_url: endpoint_url]
          end

        {:ok, %{base_url: base_url} = model} =
          Jido.AI.Model.from({String.to_atom(provider), model_config})

        %{
          model: model,
          mode: :json_schema,
          prompt: prompt,
          response_model: @response_model,
          max_retries: 2
        }
        |> Jido.AI.Actions.Instructor.run(%{})
        |> case do
          {:ok, %{result: result}, _} ->
            Models.create_model_log(params, "success", base_url, start_time)
            {:ok, result}

          {:error, reason, _} ->
            Models.create_model_log(params, "failed", base_url, start_time)
            AiAgents.format_error(reason)
        end
      end
    end
  end
end
