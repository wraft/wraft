defmodule WraftDocWeb.SignupController do
  use WraftDocWeb, :controller

  alias WraftDoc.Account

  def new(conn, _params) do
    changeset = Account.change_user()
    render(conn, changeset: changeset)
  end

  def create(conn, %{"user" => params}) do
    case Account.create_user(params) do
      {:ok, _user} -> redirect(conn, to: session_path(conn, :create, session: params))
      {:error, changeset} -> render(conn, "new.html", changeset: changeset)
    end
  end
end
