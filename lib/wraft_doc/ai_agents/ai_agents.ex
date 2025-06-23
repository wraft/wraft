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
  alias WraftDoc.Models
  alias WraftDoc.Models.Model
  alias WraftDoc.Models.Prompt

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

  @doc """
  Validates parameters for AI tool execution.
  """
  @spec validate_params(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_params(params) do
    content = Map.get(params, "content")
    prompt_id = Map.get(params, "prompt_id")
    prompt = Map.get(params, "prompt")

    prompt_type =
      params
      |> Map.get("prompt_type")
      |> case do
        nil ->
          nil

        type ->
          type |> String.downcase() |> String.to_atom()
      end

    model_id = Map.get(params, "model_id")

    with :ok <- validate_content(content),
         :ok <- validate_prompt_requirements(prompt_id, prompt, prompt_type),
         :ok <- validate_prompt_type(prompt_type) do
      {:ok, build_params(content, prompt_id, prompt, prompt_type, model_id)}
    end
  end

  defp validate_content(content) when content != nil or content != "", do: :ok
  defp validate_content(_), do: {:error, "Content is required"}

  defp validate_prompt_requirements(prompt_id, prompt, prompt_type) do
    cond do
      is_nil(prompt_id) and (is_nil(prompt) or prompt == "") ->
        {:error, "Either prompt_id or prompt with prompt_type is required"}

      not is_nil(prompt) and is_nil(prompt_type) ->
        {:error, "prompt_type is required when using prompt"}

      true ->
        :ok
    end
  end

  defp validate_prompt_type(prompt_type) do
    valid_types = [:suggestion, :refinement, :extraction]

    if not is_nil(prompt_type) and prompt_type not in valid_types do
      {:error, "prompt_type must be one of: suggestion, refinement, extraction"}
    else
      :ok
    end
  end

  defp build_params(content, prompt_id, prompt, prompt_type, model_id) do
    %{
      content: content,
      prompt_id: prompt_id,
      prompt: prompt,
      prompt_type: prompt_type,
      model_id: model_id
    }
  end

  @doc """
  Retrieves the specified model or returns the first available model as default.
  """
  @spec get_model_or_default(map(), String.t()) :: {:ok, Model.t()} | {:error, String.t()}
  def get_model_or_default(%{model_id: nil}, organisation_id) do
    organisation_id
    |> Models.get_default_model()
    |> case do
      %Model{} = model -> {:ok, model}
      nil -> {:error, "No default model available for this organization"}
    end
  end

  def get_model_or_default(%{model_id: model_id}, _organisation_id) do
    model_id
    |> Models.get_model()
    |> case do
      %Model{} = model -> {:ok, model}
      nil -> {:error, "Model not found"}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves prompt data either from database by ID or from inline prompt parameters.
  """
  @spec get_prompt_data(map()) :: {:ok, Prompt.t() | map()} | {:error, String.t()}
  def get_prompt_data(%{prompt_id: prompt_id}) when not is_nil(prompt_id) do
    case Models.get_prompt(prompt_id) do
      %Prompt{} = prompt -> {:ok, prompt}
      nil -> {:error, "Prompt not found"}
      {:error, error} -> {:error, error}
    end
  end

  def get_prompt_data(%{prompt: prompt, prompt_type: prompt_type}) when not is_nil(prompt) do
    {:ok, %{prompt: prompt, type: prompt_type}}
  end
end
