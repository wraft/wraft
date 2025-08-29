defmodule WraftDoc.InvitedUsers do
  @moduledoc """
  Context module for Invited Users.
  """
  require Logger

  import Ecto.Query

  alias WraftDoc.Account.Role
  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Repo

  @doc """
  Create or update an invited user.
  """
  @spec create_or_update_invited_user(String.t(), Ecto.UUID.t(), String.t(), list()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def create_or_update_invited_user(email, organisation_id, status \\ "invited", role_ids \\ []) do
    roles =
      if role_ids == [] do
        []
      else
        Role
        |> where([r], r.id in ^role_ids)
        |> Repo.all()
      end

    email
    |> get_invited_user(organisation_id)
    |> case do
      nil ->
        InvitedUser.changeset(%InvitedUser{}, %{email: email, organisation_id: organisation_id})

      invited_user ->
        invited_user = Repo.preload(invited_user, :roles)
        InvitedUser.status_changeset(invited_user, %{status: status})
    end
    |> Ecto.Changeset.put_assoc(:roles, roles)
    |> Repo.insert_or_update()
    |> case do
      {:ok, _invited_user} ->
        :ok

      {:error, changeset} ->
        Logger.error("InvitedUser Create/Update failed", changeset: changeset)
    end
  end

  @doc """
  Get an invited user by ID.
  """
  @spec get_invited_user_by_id(Ecto.UUID.t()) :: InvitedUser.t() | nil
  def get_invited_user_by_id(<<_::288>> = invited_user_id),
    do: InvitedUser |> Repo.get(invited_user_id) |> Repo.preload([:roles])

  def get_invited_user_by_id(_), do: nil

  @doc """
  Get an invited user by email and organisation ID.
  """
  @spec get_invited_user(String.t(), Ecto.UUID.t()) :: InvitedUser.t() | nil
  def get_invited_user(email, organisation_id),
    do:
      InvitedUser
      |> Repo.get_by(email: email, organisation_id: organisation_id)
      |> Repo.preload([:roles])

  @doc """
  List all invited users for the current organisation.
  """
  @spec list_invited_users(User.t()) :: [InvitedUser.t()]
  def list_invited_users(%{current_org_id: organisation_id} = _current_user),
    do:
      InvitedUser
      |> where([i], i.organisation_id == ^organisation_id)
      |> where([i], i.status != "joined")
      |> order_by([i], desc: i.inserted_at)
      |> Repo.all()
      |> Repo.preload([:roles])
end
