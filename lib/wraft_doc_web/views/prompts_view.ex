defmodule WraftDocWeb.Api.V1.PromptsView do
  use WraftDocWeb, :view

  alias WraftDoc.Models.Prompt

  @doc """
  Renders a list of prompts.
  """
  def index(%{prompts: prompts}) do
    %{data: for(prompts <- prompts, do: data(prompts))}
  end

  @doc """
  Renders a single prompts.
  """
  def show(%{prompt: prompt}) do
    %{data: data(prompt)}
  end

  defp data(%Prompt{} = prompt) do
    %{
      id: prompt.id,
      title: prompt.title,
      prompt: prompt.prompt,
      status: prompt.status,
      model_id: prompt.model_id
    }
  end
end
