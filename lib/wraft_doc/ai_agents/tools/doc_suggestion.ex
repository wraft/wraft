defmodule WraftDoc.AiAgents.Tools.DocSuggestion do
  @moduledoc """
  Tool for generating document suggestions based on a prompt and markdown content.
  """
  use Jido.Action,
    name: "doc_suggestion",
    description: "Converts markdown document text into structured data based on a prompt",
    schema: [
      prompt: [type: :string, required: true, doc: "Instructions for how to structure the doc"],
      markdown: [type: :string, required: true, doc: "The markdown text content to process"]
    ]

  alias WraftDoc.AiAgents
  alias WraftDoc.AiAgents.ResponseModel.Suggestions
  alias WraftDoc.Models

  def run(
        %{
          model: %{model_name: model_name, provider: provider, auth_key: auth_key},
          prompt: %{prompt: prompt_text},
          content: content
        } =
          params,
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

    {:ok, %{base_url: base_url} = model} =
      Jido.AI.Model.from(
        {String.to_atom(provider),
         [
           model: model_name,
           api_key: auth_key
         ]}
      )

    %{
      model: model,
      mode: :json_schema,
      prompt: prompt,
      response_model: Suggestions,
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
