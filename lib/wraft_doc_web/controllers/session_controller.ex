defmodule WraftDocWeb.SessionController do
  @moduledoc """
  Session controller module handles session for admin
  """
  use WraftDocWeb, :controller

  alias WraftDoc.{Account, Account.User}

  def new(conn, _params) do
    changeset = Account.change_user()
    render(conn, changeset: changeset)
  end

  def create(conn, %{"session" => params}) do
    with %User{} = user <- Account.admin_find(params["email"]),
         %User{} = user <- Account.authenticate_admin(%{user: user, password: params["password"]}) do
      conn
      |> put_session(:admin_id, user.uuid)
      |> put_flash(:info, "Signed in succesfully")
      |> redirect(to: kaffy_home_path(conn, :index))
    else
      _ ->
        conn
        |> put_flash(:error, "Please provide the correct login credentials to login")
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
