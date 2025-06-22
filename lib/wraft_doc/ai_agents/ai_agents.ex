defmodule WraftDoc.AiAgents do
  @moduledoc """
  AI Agents execution system for document processing tasks.

  This module provides a unified interface for executing different types of AI agents
  that perform various document processing operations. It supports three main agent types:

  - **Extraction**: Extracts structured data from documents (entities, dates, financial details)
  - **Suggestion**: Provides intelligent suggestions for document improvement
  - **Refinement**: Refines and improves document content quality

  ## Agent Types

  The module supports the following agent types through specialized modules:

  - `:extraction` - Handled by `WraftDoc.AiAgents.Tools.DocExtraction`
  - `:suggestion` - Handled by `WraftDoc.AiAgents.Tools.DocSuggestion`
  - `:refinement` - Handled by `WraftDoc.AiAgents.Tools.DocRefinement`

  ## Usage

  Each agent requires:
  - A user context for authorization and organization scoping
  - An AI model configuration for processing
  - A prompt that defines the specific task and agent type
  - Content to be processed

  ## Examples

      # Execute an extraction agent
      iex> WraftDoc.AiAgents.execute(user, model, extraction_prompt, content)
      {:ok, %Extraction{entities: [...], dates: [...], financial_details: [...]}}

      # Execute a suggestion agent
      iex> WraftDoc.AiAgents.execute(user, model, suggestion_prompt, content)
      {:ok, %Suggestions{suggestions: [...]}}

      # Execute a refinement agent
      iex> WraftDoc.AiAgents.execute(user, model, refinement_prompt, content)
      {:ok, "Refined content here..."}

  ## Error Handling

  Returns `{:error, "Invalid Prompt Type"}` if the prompt type is not supported.
  Individual agents may return their own specific error types.
  """

  alias WraftDoc.AiAgents.Tools.DocExtraction
  alias WraftDoc.AiAgents.Tools.DocRefinement
  alias WraftDoc.AiAgents.Tools.DocSuggestion

  @agent_modules %{
    extraction: DocExtraction,
    suggestion: DocSuggestion,
    refinement: DocRefinement
  }

  @doc """
  Executes an AI agent with the given model, prompt, and content.
  """
  @spec execute(User.t(), Model.t(), Prompt.t(), String.t()) ::
          {:ok, Extraction.t()} | {:ok, Suggestions.t()} | {:ok, String.t()}
  def execute(current_user, model, %{type: type} = prompt, content) do
    if agent_module = Map.get(@agent_modules, type) do
      agent_module.run(%{prompt: prompt, content: content, model: model, user: current_user}, %{})
    else
      {:error, "Invalid Prompt Type"}
    end
  end
end
