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

  @providers %{
    "openai" => :openai,
    "google" => :google,
    "anthropic" => :anthropic,
    "ollama" => :ollama,
    "llamacpp" => :openai,
    "groq" => :groq,
    "mistral" => :mistral,
    "openrouter" => :openrouter
  }

  @endpoint_required ["llamacpp", "ollama"]

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
