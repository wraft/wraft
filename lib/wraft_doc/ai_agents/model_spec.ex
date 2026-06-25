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
    :zai_coding_plan,
    # ReqLLM's dedicated :ollama provider sends a structured-output request
    # body Ollama's /v1 endpoint rejects with "EOF"; routed through the
    # OpenAI-compatible alias below instead.
    :ollama
  ]

  @endpoint_required [:vllm]

  @aliases [
    %{value: "llamacpp", reqllm: :openai, label: "llama.cpp", requires_endpoint: true},
    %{value: "ollama", reqllm: :openai, label: "Ollama", requires_endpoint: true},
    %{
      value: "nvidia",
      reqllm: :openai,
      label: "NVIDIA NIM",
      requires_endpoint: false,
      base_url: "https://integrate.api.nvidia.com/v1"
    }
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
        # `|| humanize/1` (not Map.get's default) so a present-but-nil catalog
        # name still falls back to a string and never breaks the downcase sort.
        label: Map.get(names, id) || humanize(id),
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
      |> Enum.filter(&(is_map(&1.capabilities) and &1.capabilities.chat and not &1.deprecated))
      |> Enum.map(&%{value: &1.model, label: &1.name || &1.model})
      |> Enum.sort_by(&String.downcase(&1.label))
    else
      _alias_local_or_unsupported -> []
    end
  rescue
    # Mirror provider_names/0: a missing/changed llm_db catalog must not crash
    # the providers endpoint — degrade to an empty model list instead.
    _error -> []
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
        base_url = endpoint_url || alias_base_url(provider)

        cond do
          requires_endpoint and is_nil(endpoint_url) ->
            {:error, "endpoint_url is required for provider: #{provider}"}

          is_nil(base_url) ->
            {:ok, %{provider: reqllm_id, id: model_name}}

          true ->
            {:ok, %{provider: reqllm_id, id: model_name, base_url: base_url}}
        end
    end
  end

  defp alias_base_url(provider) do
    case Enum.find(@aliases, &(&1.value == provider)) do
      %{} = alias_def -> Map.get(alias_def, :base_url)
      _ -> nil
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
    Enum.reject(ReqLLM.Providers.list(), &(&1 in @denied))
  end

  defp provider_names do
    Map.new(LLMDB.providers(), &{&1.id, &1.name})
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
