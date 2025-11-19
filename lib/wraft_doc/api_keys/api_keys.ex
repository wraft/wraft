defmodule WraftDoc.ApiKeys do
  @moduledoc """
  The ApiKeys context - handles all API key management operations.
  """
  import Ecto.Query
  
  alias WraftDoc.Account.{Role, User}
  alias WraftDoc.ApiKeys.ApiKey
  alias WraftDoc.Documents.InstanceApprovalSystem
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  @doc """
  Get all API keys for an organisation.
  """
  @spec list_api_keys(User.t(), map()) :: Scrivener.Page.t()
  def list_api_keys(%User{} = current_user, params \\ %{}) do
    ApiKey
    |> where([k], k.organisation_id == ^current_user.current_org_id)
    |> order_by([k], desc: k.inserted_at)
    |> preload([:user, :created_by])
    |> Repo.paginate(params)
  end

  @doc """
  Get a single API key by ID for the current user's organisation.
  """
  @spec get_api_key(User.t(), binary()) :: ApiKey.t() | nil
  def get_api_key(%User{} = current_user, api_key_id) do
    ApiKey
    |> where([k], k.id == ^api_key_id)
    |> where([k], k.organisation_id == ^current_user.current_org_id)
    |> preload([:user, :created_by])
    |> Repo.one()
  end

  @doc """
  Get an API key by the actual key string (for authentication).
  This extracts the prefix from the key and uses it for faster lookup.
  """
  @spec get_api_key_by_key(binary()) :: ApiKey.t() | nil
  def get_api_key_by_key("wraft_" <> rest = full_key) do
    # Extract prefix (first 8 characters after "wraft_")
    prefix = String.slice(rest, 0..7)
    
    # Find all keys with this prefix and check each one
    ApiKey
    |> where([k], k.key_prefix == ^prefix)
    |> where([k], k.is_active == true)
    |> preload([:user, :organisation])
    |> Repo.all()
    |> Enum.find(fn api_key ->
      ApiKey.verify_key?(api_key, full_key) and ApiKey.valid?(api_key)
    end)
  end

  def get_api_key_by_key(_), do: nil

  @doc """
  Create a new API key.
  Returns the API key struct with the unhashed key in the virtual field.
  **Important**: The unhashed key is only available immediately after creation!
  """
  @spec create_api_key(User.t(), map()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def create_api_key(%User{} = current_user, attrs) do
    attrs =
      attrs
      |> Map.put("organisation_id", current_user.current_org_id)
      |> Map.put("created_by_id", current_user.id)
      |> Map.put_new("user_id", current_user.id)

    %ApiKey{}
    |> ApiKey.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update an API key.
  """
  @spec update_api_key(ApiKey.t(), map()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def update_api_key(%ApiKey{} = api_key, attrs) do
    api_key
    |> ApiKey.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete an API key.
  """
  @spec delete_api_key(ApiKey.t()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  @doc """
  Toggle the active status of an API key.
  """
  @spec toggle_api_key_status(ApiKey.t()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def toggle_api_key_status(%ApiKey{is_active: is_active} = api_key) do
    update_api_key(api_key, %{is_active: !is_active})
  end

  @doc """
  Record API key usage.
  Updates last_used_at timestamp and increments usage_count.
  """
  @spec record_usage(ApiKey.t()) :: {:ok, ApiKey.t()} | {:error, Ecto.Changeset.t()}
  def record_usage(%ApiKey{} = api_key) do
    api_key
    |> ApiKey.usage_changeset(%{
      last_used_at: DateTime.truncate(DateTime.utc_now(), :second),
      usage_count: api_key.usage_count + 1
    })
    |> Repo.update()
  end

  @doc """
  Verify an API key and return the associated user and organisation.
  Performs all validation checks (expiration, active status, IP whitelist, etc.)
  """
  @spec verify_api_key(binary(), binary() | nil) ::
          {:ok, %{api_key: ApiKey.t(), user: User.t(), organisation: Organisation.t()}}
          | {:error, atom()}
  def verify_api_key(key, remote_ip \\ nil) do
    case get_api_key_by_key(key) do
      nil ->
        {:error, :invalid_api_key}

      api_key ->
        with :ok <- check_active(api_key),
             :ok <- check_expiration(api_key),
             :ok <- check_ip_whitelist(api_key, remote_ip),
             {:ok, user} <- load_user_with_permissions(api_key) do
          # Record usage asynchronously (don't block the request)
          Task.start(fn -> record_usage(api_key) end)

          {:ok,
           %{
             api_key: api_key,
             user: user,
             organisation: api_key.organisation
           }}
        end
    end
  end

  # Private functions

  defp check_active(%ApiKey{is_active: true}), do: :ok
  defp check_active(_), do: {:error, :api_key_inactive}

  defp check_expiration(api_key) do
    if ApiKey.valid?(api_key) do
      :ok
    else
      {:error, :api_key_expired}
    end
  end

  defp check_ip_whitelist(_api_key, nil), do: :ok

  defp check_ip_whitelist(api_key, remote_ip) do
    if ApiKey.ip_allowed?(api_key, remote_ip) do
      :ok
    else
      {:error, :ip_not_whitelisted}
    end
  end

  defp load_user_with_permissions(%ApiKey{user_id: user_id, organisation_id: org_id}) do
    # Load the user and verify they belong to the organisation
    user =
      User
      |> join(:inner, [u], uo in "users_organisations",
        on: u.id == uo.user_id and uo.organisation_id == type(^org_id, Ecto.UUID)
      )
      |> where([u], u.id == type(^user_id, Ecto.UUID))
      |> where([u, uo], is_nil(uo.deleted_at))
      |> Repo.one()

    case user do
      nil ->
        {:error, :user_not_found}

      %User{} = user_struct ->
        # Preload roles for this organisation (same pattern as CurrentOrganisation plug)
        roles_preload_query =
          from(r in Role, where: r.organisation_id == type(^org_id, Ecto.UUID))

        # Preload instances_to_approve (same as CurrentUser plug)
        instances_to_approve_query =
          from(ias in InstanceApprovalSystem, where: ias.flag == false)

        user_with_associations =
          Repo.preload(user_struct, [
            :profile,
            roles: roles_preload_query,
            instances_to_approve: instances_to_approve_query
          ])

        # Process roles to extract names and permissions (same logic as CurrentOrganisation)
        %{names: role_names, permissions: permissions} =
          Enum.reduce(user_with_associations.roles, %{names: [], permissions: []}, fn role, acc ->
            add_role_names_and_permissions(role, acc)
          end)

        user_with_data =
          user_with_associations
          |> Map.put(:current_org_id, org_id)
          |> Map.put(:permissions, permissions)
          |> Map.put(:role_names, role_names)

        {:ok, user_with_data}
    end
  end

  # Helper function to accumulate role names and permissions (same as CurrentOrganisation)
  defp add_role_names_and_permissions(role, roles_acc) do
    permissions = roles_acc.permissions |> Kernel.++(role.permissions) |> Enum.uniq()
    names = [role.name | roles_acc.names]
    %{names: names, permissions: permissions}
  end

  @doc """
  Check if rate limit is exceeded for an API key.
  Returns {:ok, api_key} if within limit, {:error, :rate_limit_exceeded} otherwise.
  
  This is a simple hourly rate limit check.
  For production, consider using a more sophisticated rate limiting solution.
  """
  @spec check_rate_limit(ApiKey.t()) :: {:ok, ApiKey.t()} | {:error, :rate_limit_exceeded}
  def check_rate_limit(%ApiKey{rate_limit: _rate_limit, last_used_at: nil} = api_key) do
    # First use, always allowed
    {:ok, api_key}
  end

  def check_rate_limit(%ApiKey{rate_limit: rate_limit, last_used_at: last_used_at} = api_key) do
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    # Simple check: reset counter if last use was more than an hour ago
    if DateTime.compare(last_used_at, one_hour_ago) == :lt do
      {:ok, api_key}
    else
      # Check usage count in the current hour
      # This is a simplified version - for production, use a proper rate limiting solution
      current_hour_usage = get_usage_count_since(api_key, one_hour_ago)

      if current_hour_usage >= rate_limit do
        {:error, :rate_limit_exceeded}
      else
        {:ok, api_key}
      end
    end
  end

  defp get_usage_count_since(%ApiKey{id: id, last_used_at: last_used_at}, since) do
    # For a simple implementation, we assume usage_count tracks current hour
    # In production, you'd want to use Redis or a proper rate limiting solution
    if DateTime.compare(last_used_at, since) == :gt do
      # Last use was within the hour, count from there
      ApiKey
      |> where([k], k.id == ^id)
      |> select([k], k.usage_count)
      |> Repo.one() || 0
    else
      0
    end
  end
end

