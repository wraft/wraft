defmodule WraftDoc.CloudImport.RepositoryCloudTokens do
  @moduledoc """
  Context for managing Cloud Auth Tokens.
  """
  import Ecto.Query, warn: false

  alias WraftDoc.Account.User
  alias WraftDoc.CloudImport.RepositoryCloudToken
  alias WraftDoc.Repo

  @doc """
  Creates a Cloud Auth Token.
  """
  @spec insert_auth_token!(User.t(), map()) :: RepositoryCloudToken.t()
  def insert_auth_token!(%User{id: user_id}, params) do
    params = Map.put(params, :user_id, user_id)

    %RepositoryCloudToken{}
    |> RepositoryCloudToken.changeset(params)
    |> Repo.insert!()
  end

  def insert_auth_token!(_, _), do: raise("Unexpected arguments passed.")

  @doc """
  Updates a Cloud Auth Token.
  """
  @spec update_cloud_auth_token!(User.t(), map()) ::
          {:ok, %RepositoryCloudToken{}} | {:error, Ecto.Changeset.t()}
  def update_cloud_auth_token!(%RepositoryCloudToken{} = token, attrs) do
    token
    |> RepositoryCloudToken.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Cloud Auth Token.
  """
  @spec delete_cloud_auth_token(User.t(), String.t()) ::
          {:ok, %RepositoryCloudToken{}} | {:error, Ecto.Changeset.t()}
  def delete_cloud_auth_token(user_id, type) do
    query =
      from(
        a in RepositoryCloudToken,
        where: a.user_id == ^user_id,
        where: a.token_type == ^type
      )

    Repo.delete_all(query)
  end

  @doc """
  Saves token data for a user.
  """
  @spec save_token_data(User.t(), map(), atom(), map()) ::
          {:ok, RepositoryCloudToken.t()} | {:error, Ecto.Changeset.t()} | {:error, atom()}
  def save_token_data(
        %User{id: user_id} = user,
        token_data,
        provider,
        external_user_data \\ %{}
      ) do
    existing_token =
      WraftDoc.Repo.get_by(RepositoryCloudToken,
        provider: provider,
        organisation_id: user.current_org_id
      )

    if existing_token do
      {:error, :google_drive_already_exists_for_org}
    else
      params = %{
        access_token: token_data["access_token"] || token_data.access_token,
        provider: ensure_atom(provider),
        user_id: user_id,
        external_user_data: external_user_data,
        organisation_id: user.current_org_id,
        refresh_token: token_data["refresh_token"] || token_data.refresh_token,
        expires_at: calculate_expiry(token_data["expires_in"]),
        meta_data: %{
          "scope" => token_data["scope"]
        }
      }

      {:ok, insert_auth_token!(user, params)}
    end
  end

  defp calculate_expiry(nil), do: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)

  defp calculate_expiry(expires_in) when is_integer(expires_in) do
    NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in)
  end

  defp calculate_expiry(_), do: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)

  defp ensure_atom(input) do
    case input do
      atom when is_atom(atom) -> atom
      other -> String.to_atom(to_string(other))
    end
  end

  @doc """
  Retrieves the latest access token for the specified user and service.
  Returns {:ok, token} if valid token exists, nil otherwise.
  """
  @spec get_latest_token(User.t(), atom()) :: String.t() | nil
  def get_latest_token(%User{current_org_id: org_id}, type) do
    RepositoryCloudToken
    |> where([t], t.provider == ^type and t.organisation_id == ^org_id)
    |> order_by([t], desc: t.inserted_at)
    |> limit(1)
    |> select([t], t.access_token)
    |> Repo.one()
  end

  # TODO revoke token / delete token acess/refresh token (automatically delete after 1 hour)
  # @doc """
  # Revokes/deletes tokens for a specific user and provider.
  # """

  # @spec revoke_tokens(User.t(), atom()) :: :ok | {:error, any()}
  # def revoke_tokens(user, provider) do
  #   case get_cloud_import_token(user, provider) do
  #     {:ok, _token} ->
  #       # Delete the token from database
  #       case delete_cloud_import_token(user, provider) do
  #         {:ok, _} -> :ok
  #         {:error, reason} -> {:error, reason}
  #       end

  #     {:error, _} ->
  #       # Token doesn't exist, consider it already revoked
  #       :ok
  #   end
  # end

  @doc """
  Deletes a cloud import token for a user and provider.
  """
  @spec delete_cloud_import_token(User.t(), atom()) :: {:ok, any()} | {:error, any()}
  def delete_cloud_import_token(user, provider) do
    case Repo.get_by(RepositoryCloudToken, user_id: user.id, provider: provider) do
      nil -> {:ok, :not_found}
      token -> Repo.delete(token)
    end
  end

  # defp token_still_valid?(token) do
  #   case token do
  #     %{expires_at: nil} ->
  #       true

  #     %{expires_at: expires_at} when is_integer(expires_at) ->
  #       current_time = System.system_time(:second)
  #       # 5 minute buffer
  #       expires_at > current_time + 300

  #     _ ->
  #       false
  #   end
  # end

  # defp refresh_token_if_possible(user, provider, %{refresh_token: refresh_token} = _token)
  #      when is_binary(refresh_token) do
  #   with {:ok, new_token_data} <- CloudAuth.refresh_token(provider, refresh_token),
  #        {:ok, saved_token} <- save_cloud_import_token(user, new_token_data, provider) do
  #     {:ok, saved_token}
  #   else
  #     {:error, reason} -> {:error, reason}
  #   end
  # end

  # defp refresh_token_if_possible(_user, _provider, _token) do
  #   {:error, "No refresh token available"}
  # end
end
