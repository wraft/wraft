defmodule WraftDoc.InternalUsers do
  @moduledoc false

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo

  # Admin sessions expire after this many seconds regardless of cookie
  # lifetime. The endpoint references `admin_session_max_age/0` for the
  # cookie `max_age`, so the two cannot drift.
  @admin_session_max_age 60 * 60 * 12

  @doc "Admin session lifetime in seconds (shared with the endpoint cookie max_age)."
  def admin_session_max_age, do: @admin_session_max_age

  def change_internal_user, do: InternalUser.changeset(%InternalUser{})

  def get_by_email(email) do
    Repo.get_by(InternalUser, email: email)
  end

  def update_internal_user(internal_user, attrs) do
    internal_user
    |> InternalUser.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Resolves an admin from session data, enforcing the full gate:
  the admin must exist, must not be deactivated, the session must be
  younger than the max age, and the session's epoch must match the
  admin's current `session_epoch` (bumped on deactivation/password
  change, which revokes previously minted cookies).

  Both the `CurrentAdmin` plug and the LiveView `ensure_admin` hook go
  through this function so the two gates cannot drift.
  """
  @spec fetch_active_admin(map()) :: {:ok, InternalUser.t()} | :error
  def fetch_active_admin(%{"admin_id" => admin_id} = session) when is_binary(admin_id) do
    with %InternalUser{is_deactivated: false} = admin <- safe_get(admin_id),
         true <- session_fresh?(session["admin_iat"]),
         true <- session["admin_epoch"] == admin.session_epoch do
      {:ok, admin}
    else
      _ -> :error
    end
  end

  def fetch_active_admin(_session), do: :error

  @doc """
  Session values to store at sign-in; consumed by `fetch_active_admin/1`.
  """
  @spec admin_session_attrs(InternalUser.t()) :: map()
  def admin_session_attrs(%InternalUser{} = admin) do
    %{
      "admin_id" => admin.id,
      "admin_iat" => System.system_time(:second),
      "admin_epoch" => admin.session_epoch
    }
  end

  defp safe_get(admin_id) do
    Repo.get(InternalUser, admin_id)
  rescue
    Ecto.Query.CastError -> nil
  end

  defp session_fresh?(iat) when is_integer(iat),
    do: System.system_time(:second) - iat <= @admin_session_max_age

  defp session_fresh?(_iat), do: false
end
