defmodule WraftDocWeb.AdminNext.AdminAuth do
  @moduledoc """
  LiveView `on_mount` hook for the Backpex `/admin` scope.

  Reuses the existing Kaffy admin session (`session["admin_id"]` → `InternalUser`)
  so operators can stay logged in across both /admin (Kaffy) and /admin
  (Backpex) during the strangler-fig migration. On failure, halts and redirects
  to the existing Kaffy login screen.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo

  def on_mount(:ensure_admin, _params, session, socket) do
    case session["admin_id"] do
      nil ->
        {:halt, redirect(socket, to: "/admin/signin")}

      admin_id ->
        case Repo.get(InternalUser, admin_id) do
          %InternalUser{} = admin ->
            {:cont, assign(socket, :current_admin, admin)}

          _ ->
            {:halt, redirect(socket, to: "/admin/signin")}
        end
    end
  end
end
