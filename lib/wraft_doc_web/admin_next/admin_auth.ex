defmodule WraftDocWeb.AdminNext.AdminAuth do
  @moduledoc """
  LiveView `on_mount` hook for the Backpex `/admin` scope.

  Reuses the admin session (`session["admin_id"]` → `InternalUser`) so
  operators stay logged in across the /admin surfaces. The full gate
  (existence, deactivation, expiry, epoch revocation) lives in
  `WraftDoc.InternalUsers.fetch_active_admin/1`, shared with the
  `CurrentAdmin` plug so the two gates cannot drift. On failure, halts
  and redirects to the admin login screen.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  alias WraftDoc.InternalUsers

  def on_mount(:ensure_admin, _params, session, socket) do
    case InternalUsers.fetch_active_admin(session) do
      {:ok, admin} ->
        {:cont, assign(socket, :current_admin, admin)}

      :error ->
        {:halt, redirect(socket, to: "/admin/signin")}
    end
  end
end
