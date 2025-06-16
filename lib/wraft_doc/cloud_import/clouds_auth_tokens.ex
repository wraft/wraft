defmodule WraftDoc.CloudImport.CloudAuthTokens do
  @moduledoc """
  Context for managing Cloud Auth Tokens.
  """
  import Ecto.Query, warn: false
  alias WraftDoc.Account.User
  alias WraftDoc.CloudImport.CloudAuthToken
  alias WraftDoc.Repo

  @doc """
  Creates a Cloud Auth Token.
  """
  def insert_auth_token!(%User{} = _user, params) do
    %CloudAuthToken{}
    |> CloudAuthToken.changeset(params)
    |> Repo.insert!()
  end

  def insert_auth_token!(_, _), do: raise("Unexpected arguments passed.")

  @doc """
  Updates a Cloud Auth Token.
  """
  def update_cloud_auth_token(%CloudAuthToken{} = token, attrs) do
    token
    |> CloudAuthToken.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Cloud Auth Token.
  """
  def delete_cloud_auth_token(user_id, type) do
    query =
      from(
        a in CloudAuthToken,
        where: a.user_id == ^user_id,
        where: a.token_type == ^type
      )

    Repo.delete_all(query)
  end

  def save_cloud_import_token(%User{id: user_id} = user, token_data, service) do
    params = %{
      access_token: token_data.access_token,
      service: Atom.to_string(service),
      user_id: user_id,
      refresh_token: token_data.refresh_token || token_data["refresh_token"],
      expiry_datetime: calculate_expiry(token_data.expires_at),
      meta_data: %{
        "scope" => token_data.scope
      }
    }

    {:ok, insert_auth_token!(user, params)}
  end

  defp calculate_expiry(nil), do: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)

  defp calculate_expiry(expires_in) when is_integer(expires_in) do
    NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in)
  end

  defp calculate_expiry(_), do: NaiveDateTime.add(NaiveDateTime.utc_now(), 3600)

  def get_latest_token(%User{id: user_id}, type) do
    CloudAuthToken
    |> where([t], t.token_type == ^type and t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> limit(1)
    |> select([t], t.value)
    |> Repo.one()
  end
end
