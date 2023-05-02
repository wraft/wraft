defmodule WraftDocWeb.SessionController do
  @moduledoc """
  Session controller module handles session for admin
  """
  use WraftDocWeb, :controller

  alias WraftDoc.InternalUsers
  alias WraftDoc.InternalUsers.InternalUser

  def new(conn, _params) do
    changeset = InternalUsers.change_internal_user()
    render(conn, changeset: changeset)
  end

  def create(conn, %{"session" => params}) do
    with %InternalUser{} = user <- InternalUsers.get_by_email(params["email"]),
         true <- Bcrypt.verify_pass(params["password"], user.encrypted_password) do
      conn
      |> put_session(:admin_id, user.id)
      |> put_flash(:info, "Signed in successfully.")
      |> redirect(to: kaffy_home_path(conn, :index))
    else
      _ ->
        conn
        |> put_flash(:error, "Please provide the correct login credentials to login.")
        |> redirect(to: session_path(conn, :new))
    end
  end

  @doc """
  Delete a session.
  """
  def delete(conn, _) do
    conn
    |> delete_session(:admin_id)
    |> put_flash(:info, "Signed out successfully.")
    |> redirect(to: session_path(conn, :new))
  end
end
