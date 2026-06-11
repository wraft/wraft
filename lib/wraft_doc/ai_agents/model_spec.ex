defmodule WraftDoc.AiAgents.ModelSpec do
  @moduledoc """
  Maps `ai_model` records to ReqLLM inline model specs.

  Providers are stored as free-form strings in the database; this module is
  the single place they are translated to ReqLLM provider atoms. llama.cpp
  servers expose an OpenAI-compatible API, so `llamacpp` models are routed
  through the `:openai` provider with the model's `endpoint_url` as
  `base_url`.
  """

  alias WraftDoc.Models.Model

  @provider_defs [
    %{value: "openai", reqllm: :openai, label: "OpenAI", requires_endpoint: false},
    %{value: "google", reqllm: :google, label: "Google Gemini", requires_endpoint: false},
    %{value: "anthropic", reqllm: :anthropic, label: "Anthropic", requires_endpoint: false},
    %{value: "ollama", reqllm: :ollama, label: "Ollama", requires_endpoint: true},
    %{value: "llamacpp", reqllm: :openai, label: "llama.cpp", requires_endpoint: true},
    %{value: "groq", reqllm: :groq, label: "Groq", requires_endpoint: false},
    %{value: "mistral", reqllm: :mistral, label: "Mistral", requires_endpoint: false},
    %{value: "openrouter", reqllm: :openrouter, label: "OpenRouter", requires_endpoint: false}
  ]

  @providers Map.new(@provider_defs, &{&1.value, &1.reqllm})
  @endpoint_required @provider_defs
                     |> Enum.filter(& &1.requires_endpoint)
                     |> Enum.map(& &1.value)

  @doc """
  Provider values accepted in the `ai_model` table.
  """
  @spec supported_providers() :: [String.t()]
  def supported_providers, do: Enum.map(@provider_defs, & &1.value)

  @doc """
  Provider options for API consumers (settings UI dropdowns).
  """
  @spec provider_options() :: [map()]
  def provider_options,
    do: Enum.map(@provider_defs, &Map.take(&1, [:value, :label, :requires_endpoint]))

  @doc """
  Builds a ReqLLM inline model spec from an `ai_model` record.
  """
  @spec build(Model.t() | map()) :: {:ok, map()} | {:error, String.t()}
  def build(%{provider: provider, model_name: model_name} = model) do
    endpoint_url = Map.get(model, :endpoint_url)

    cond do
      not Map.has_key?(@providers, provider) ->
        {:error, "Unsupported AI provider: #{provider}"}

      provider in @endpoint_required and is_nil(endpoint_url) ->
        {:error, "endpoint_url is required for provider: #{provider}"}

      is_nil(endpoint_url) ->
        {:ok, %{provider: @providers[provider], id: model_name}}

      true ->
        {:ok, %{provider: @providers[provider], id: model_name, base_url: endpoint_url}}
    end
  end
end
