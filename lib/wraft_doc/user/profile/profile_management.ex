defmodule WraftDoc.ProfileManagement do
  @moduledoc """
      This module handles all the repo connections of the
      profile context
  """
  alias WraftDoc.Repo

  alias WraftDoc.ProfileManagement.Profile

  def update_profile(conn, params) do
    current_user = conn.assigns.current_user.id

    user =
      Profile
      |> Repo.get_by(user_id: current_user)
      |> Profile.changeset(params)

    case Repo.update(user) do
      changeset = {:error, _} ->
        changeset

      {:ok, profile_struct} ->
        Repo.preload(profile_struct, :user)
        |> Repo.preload(:country)
    end
  end
end
