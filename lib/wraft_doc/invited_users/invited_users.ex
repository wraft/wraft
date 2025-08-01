defmodule WraftDoc.InvitedUsers do
  @moduledoc """
  Context module for Invited Users.
  """
  require Logger

  import Ecto.Query

  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Repo

  def create_or_update_invited_user(email, organisation_id, status \\ "invited") do
    email
    |> get_invited_user(organisation_id)
    |> case do
      nil ->
        InvitedUser.changeset(%InvitedUser{}, %{email: email, organisation_id: organisation_id})

      invited_user ->
        InvitedUser.status_changeset(invited_user, %{status: status})
    end
    |> Repo.insert_or_update()
    |> case do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.error("InvitedUser Create/Update failed", changeset: changeset)
    end
  end

  def get_invited_user(email, organisation_id),
    do: Repo.get_by(InvitedUser, email: email, organisation_id: organisation_id)

  def list_invited_users(%{current_org_id: organisation_id} = _current_user),
    do: Repo.all(from(i in InvitedUser, where: i.organisation_id == ^organisation_id))
end
