defmodule WraftDoc.AiAgents.ModelSpec do
  @moduledoc """
  Maps `ai_model` records to ReqLLM inline model specs.

  The provider list is derived at runtime from the providers ReqLLM
  actually registers (`ReqLLM.Providers.list/0`), with display names from
  the llm_db catalog, so upgrading req_llm picks up new providers without
  code changes here. A small policy layer on top:

    * `@denied` removes providers that cannot work with the single
      api_key + endpoint_url credentials stored on `ai_model`
      (cloud-IAM auth, deployment-scoped configs) or are not
      chat-completion providers.
    * `@endpoint_required` marks self-hosted inference servers that have
      no default public endpoint.
    * `@aliases` adds Wraft-specific providers ReqLLM has no id for;
      llama.cpp servers expose an OpenAI-compatible API, so they are
      routed through the `:openai` provider with the model's
      `endpoint_url` as `base_url`.
  """

  alias WraftDoc.Models.Model

  @denied [
    :alibaba_cn,
    :amazon_bedrock,
    :azure,
    :elevenlabs,
    :google_vertex,
    :openai_codex,
    :zai_coder,
    :zai_coding_plan
  ]

  @endpoint_required [:ollama, :vllm]

  @aliases [
    %{value: "llamacpp", reqllm: :openai, label: "llama.cpp", requires_endpoint: true}
  ]

  @doc """
  Provider values accepted in the `ai_model` table.
  """
  @spec supported_providers() :: [String.t()]
  def supported_providers do
    Enum.map(reqllm_providers(), &Atom.to_string/1) ++ Enum.map(@aliases, & &1.value)
  end

  @doc """
  Provider options for API consumers (settings UI dropdowns).
  """
  @spec provider_options() :: [map()]
  def provider_options do
    names = provider_names()

    reqllm_providers()
    |> Enum.map(fn id ->
      %{
        value: Atom.to_string(id),
        label: Map.get(names, id, humanize(id)),
        requires_endpoint: id in @endpoint_required
      }
    end)
    |> Kernel.++(Enum.map(@aliases, &Map.take(&1, [:value, :label, :requires_endpoint])))
    |> Enum.sort_by(&String.downcase(&1.label))
  end

  @doc """
  Known chat models for a provider, from the llm_db catalog.

  Returns an empty list for unknown providers and for self-hosted/alias
  providers (llamacpp, ollama, vllm), where model names are free-form.
  """
  @spec model_options(String.t()) :: [map()]
  def model_options(provider) do
    with nil <- Enum.find(@aliases, &(&1.value == provider)),
         {:ok, id, false} <- resolve_provider(provider) do
      id
      |> LLMDB.models()
      |> Enum.filter(&(&1.capabilities.chat and not &1.deprecated))
      |> Enum.map(&%{value: &1.model, label: &1.name || &1.model})
      |> Enum.sort_by(&String.downcase(&1.label))
    else
      _alias_local_or_unsupported -> []
    end
  end

  @doc """
  Builds a ReqLLM inline model spec from an `ai_model` record.
  """
  @spec build(Model.t() | map()) :: {:ok, map()} | {:error, String.t()}
  def build(%{provider: provider, model_name: model_name} = model) do
    endpoint_url = Map.get(model, :endpoint_url)

    case resolve_provider(provider) do
      {:error, _reason} = error ->
        error

      {:ok, reqllm_id, requires_endpoint} ->
        cond do
          requires_endpoint and is_nil(endpoint_url) ->
            {:error, "endpoint_url is required for provider: #{provider}"}

          is_nil(endpoint_url) ->
            {:ok, %{provider: reqllm_id, id: model_name}}

          true ->
            {:ok, %{provider: reqllm_id, id: model_name, base_url: endpoint_url}}
        end
    end
  end

  defp resolve_provider(provider) do
    case Enum.find(@aliases, &(&1.value == provider)) do
      %{reqllm: reqllm_id, requires_endpoint: requires_endpoint} ->
        {:ok, reqllm_id, requires_endpoint}

      nil ->
        id = String.to_existing_atom(provider)

        if id in reqllm_providers() do
          {:ok, id, id in @endpoint_required}
        else
          {:error, "Unsupported AI provider: #{provider}"}
        end
    end
  rescue
    ArgumentError -> {:error, "Unsupported AI provider: #{provider}"}
  end

  defp reqllm_providers do
    ReqLLM.Providers.list() |> Enum.reject(&(&1 in @denied))
  end

  defp provider_names do
    LLMDB.providers()
    |> Map.new(&{&1.id, &1.name})
  rescue
    _error -> %{}
  end

  defp humanize(id) do
    id
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
