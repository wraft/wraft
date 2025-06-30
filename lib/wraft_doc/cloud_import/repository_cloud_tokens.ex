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
  @spec save_token_data(User.t(), String.t(), map(), String.t(), map()) ::
          {:ok, %RepositoryCloudToken{}} | {:error, Ecto.Changeset.t()}
  def save_token_data(
        %User{id: user_id} = user,
        organisation_id,
        token_data,
        provider,
        _external_user_data \\ %{}
      ) do
    params = %{
      access_token: token_data["access_token"] || token_data.access_token,
      provider: ensure_atom(provider),
      user_id: user_id,
      organisation_id: organisation_id,
      refresh_token: token_data["refresh_token"] || token_data.refresh_token,
      expires_at: calculate_expiry(token_data["expires_in"]),
      meta_data: %{
        "scope" => token_data["scope"]
      }
    }

    {:ok, insert_auth_token!(user, params)}
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
  def get_latest_token(%User{id: user_id}, type) do
    RepositoryCloudToken
    |> where([t], t.service == ^type and t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> limit(1)
    |> select([t], t.access_token)
    |> Repo.one()
  end

  # Add these functions to your existing WraftDoc.CloudImport.CloudAuthTokens module

  # @doc """
  # Gets a valid token for the specified user and service.
  # Returns {:ok, token} if valid token exists, {:error, reason} otherwise.
  # """

  # @spec get_valid_token(User.t(), atom()) :: {:ok, map()} | {:error, String.t()}
  # def get_valid_token(user, service) do
  #   case get_cloud_import_token(user, service) do
  #     {:ok, token} ->
  #       if token_still_valid?(token) do
  #         {:ok, token}
  #       else
  #         # Try to refresh the token
  #         case refresh_token_if_possible(user, service, token) do
  #           {:ok, new_token} -> {:ok, new_token}
  #           {:error, _} -> {:error, "Token expired and refresh failed"}
  #         end
  #       end

  #     {:error, reason} ->
  #       {:error, reason}
  #   end
  # end

  # @doc """
  # Revokes/deletes tokens for a specific user and service.
  # """

  # @spec revoke_tokens(User.t(), atom()) :: :ok | {:error, any()}
  # def revoke_tokens(user, service) do
  #   case get_cloud_import_token(user, service) do
  #     {:ok, _token} ->
  #       # Delete the token from database
  #       case delete_cloud_import_token(user, service) do
  #         {:ok, _} -> :ok
  #         {:error, reason} -> {:error, reason}
  #       end

  #     {:error, _} ->
  #       # Token doesn't exist, consider it already revoked
  #       :ok
  #   end
  # end

  # @doc """
  # Gets a cloud import token for a user and service.
  # This function should already exist in your module, but here's a reference implementation.
  # """

  # @spec get_cloud_import_token(User.t(), atom()) :: {:ok, map()} | {:error, String.t()}
  # def get_cloud_import_token(user, service) do
  #   # This should query your database/storage for the token
  #   # Example implementation:
  #   case Repo.get_by(CloudImportToken, user_id: user.id, service: service) do
  #     nil -> {:error, "Token not found"}
  #     token -> {:ok, token}
  #   end
  # end

  @doc """
  Deletes a cloud import token for a user and service.
  """
  @spec delete_cloud_import_token(User.t(), atom()) :: {:ok, any()} | {:error, any()}
  def delete_cloud_import_token(user, provider) do
    case Repo.get_by(RepositoryCloudToken, user_id: user.id, service: provider) do
      nil -> {:ok, :not_found}
      token -> Repo.delete(token)
    end
  end

  # Private helper functions

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

  # defp refresh_token_if_possible(user, service, %{refresh_token: refresh_token} = _token)
  #      when is_binary(refresh_token) do
  #   with {:ok, new_token_data} <- CloudAuth.refresh_token(service, refresh_token),
  #        {:ok, saved_token} <- save_cloud_import_token(user, new_token_data, service) do
  #     {:ok, saved_token}
  #   else
  #     {:error, reason} -> {:error, reason}
  #   end
  # end

  # defp refresh_token_if_possible(_user, _service, _token) do
  #   {:error, "No refresh token available"}
  # end
end
