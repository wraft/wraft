defmodule WraftDoc.AiAgents do
  @moduledoc """
  This module provides functions for executing AI agents.
  """
  alias WraftDoc.AiAgents.Tools.DocExtraction
  alias WraftDoc.AiAgents.Tools.DocRefinement
  alias WraftDoc.AiAgents.Tools.DocSuggestion

  @doc """
  Executes an AI agent with the given model, prompt, and content.
  """
  @spec execute(User.t(), Model.t(), Prompt.t(), String.t()) ::
          {:ok, Extraction.t()} | {:ok, Suggestions.t()} | {:ok, String.t()}
  def execute(current_user, model, %{type: :extraction} = prompt, content),
    do:
      DocExtraction.run(
        %{prompt: prompt, content: content, model: model, user: current_user},
        %{}
      )

  def execute(current_user, model, %{type: :suggestion} = prompt, content),
    do:
      DocSuggestion.run(
        %{prompt: prompt, content: content, model: model, user: current_user},
        %{}
      )

  def execute(current_user, model, %{type: :refinement} = prompt, content),
    do:
      DocRefinement.run(
        %{prompt: prompt, content: content, model: model, user: current_user},
        %{}
      )

  def execute(_, _, _, _),
    do: {:error, "Invalid Prompt Type"}
end
