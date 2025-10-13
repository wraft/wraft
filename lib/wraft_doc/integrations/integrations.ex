defmodule WraftDoc.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false
  alias WraftDoc.Account.User
  alias WraftDoc.Integrations.Integration
  alias WraftDoc.Repo

  @doc """
  Returns the list of integrations for an organization.
  """
  @spec list_organisation_integrations(User.t()) :: [Integration.t()]
  def list_organisation_integrations(%User{current_org_id: organisation_id} = _current_user) do
    Integration
    |> where([i], i.organisation_id == ^organisation_id)
    |> Repo.all()
  end

  @doc """
  Gets a single integration.
  """
  @spec get_integration(Ecto.UUID.t()) :: Integration.t() | nil
  def get_integration(id), do: Repo.get(Integration, id)

  @doc """
  Gets a single integration by provider for an organization.
  """
  @spec get_integration_by_provider(Ecto.UUID.t(), String.t()) :: Integration.t() | nil
  def get_integration_by_provider(organisation_id, provider) do
    Integration
    |> where([i], i.organisation_id == ^organisation_id and i.provider == ^provider)
    |> Repo.one()
  end

  @doc """
  Updates the metadata of an integration.
  """
  @spec update_metadata(Integration.t(), map()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def update_metadata(%Integration{} = integration, new_metadata) when is_map(new_metadata) do
    merged_metadata = Map.merge(integration.metadata || %{}, new_metadata)

    integration
    |> Integration.changeset(%{metadata: merged_metadata})
    |> Repo.update()
  end

  @doc """
  Creates an integration.
  """
  @spec create_integration(map()) :: {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def create_integration(attrs \\ %{}) do
    attrs = maybe_add_category(attrs)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an integration.
  """
  @spec update_integration(Integration.t(), map()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def update_integration(%Integration{} = integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an integration.
  """
  @spec delete_integration(Integration.t()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def delete_integration(%Integration{} = integration), do: Repo.delete(integration)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking integration changes.
  """
  @spec change_integration(Integration.t(), map()) :: Ecto.Changeset.t()
  def change_integration(%Integration{} = integration, attrs \\ %{}),
    do: Integration.changeset(integration, attrs)

  @doc """
  Enables an integration for an organization.
  """
  @spec enable_integration(Integration.t()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def enable_integration(%Integration{} = integration),
    do: update_integration(integration, %{enabled: true})

  @doc """
  Disables an integration for an organization.
  """
  @spec disable_integration(Integration.t()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def disable_integration(%Integration{} = integration),
    do: update_integration(integration, %{enabled: false})

  @doc """
  Updates integration events.
  """
  @spec update_integration_events(Integration.t(), list()) ::
          {:ok, Integration.t()} | {:error, Ecto.Changeset.t()}
  def update_integration_events(%Integration{} = integration, events) when is_list(events),
    do: update_integration(integration, %{events: events})

  @doc """
  Checks if an integration is enabled for an organization.
  """
  @spec integration_enabled?(Ecto.UUID.t(), String.t()) :: boolean()
  def integration_enabled?(organisation_id, provider) do
    organisation_id
    |> get_integration_by_provider(provider)
    |> case do
      %Integration{enabled: enabled} -> enabled
      nil -> false
    end
  end

  @doc """
  Gets the configuration for an integration.
  """
  @spec get_integration_config(Ecto.UUID.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def get_integration_config(organisation_id, provider) do
    case get_integration_by_provider(organisation_id, provider) do
      %Integration{enabled: true, config: config} -> {:ok, config}
      %Integration{enabled: false} -> {:error, :integration_disabled}
      nil -> {:error, :integration_not_found}
    end
  end

  @doc """
  Gets the latest token for an integration.
  """
  @spec get_latest_token(User.t(), atom()) :: String.t() | nil
  def get_latest_token(%User{current_org_id: org_id}, type) do
    Integration
    |> where([i], i.provider == ^type and i.organisation_id == ^org_id)
    |> order_by([i], desc: i.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil ->
        {:error, "No integration found for #{type}"}

      %Integration{metadata: metadata} when metadata in [%{}, nil] ->
        {:error, "Integration found but no tokens available"}

      %Integration{metadata: %{"access_token" => token} = _metadata} ->
        {:ok, token}
    end
  end

  @doc """
  Returns all available categories.
  """
  @spec available_categories() :: [String.t()]
  def available_categories, do: Integration.available_categories()

  @doc """
  Returns all providers for a specific category.
  """
  @spec providers_by_category(String.t() | atom()) :: [String.t()]
  def providers_by_category(category) do
    Enum.filter(Integration.available_providers(), fn provider ->
      Integration.provider_category(provider) == category
    end)
  end

  defp maybe_add_category(%{"provider" => provider} = attrs) do
    if Map.has_key?(attrs, "category") do
      attrs
    else
      Map.put(attrs, "category", Integration.provider_category(provider))
    end
  end

  defp maybe_add_category(attrs), do: attrs
end
