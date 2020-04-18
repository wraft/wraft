defmodule WraftDocWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use WraftDocWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(WraftDocWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, :invalid}) do
    body =
      Poison.encode!(%{error: "Your email-password combination doesn't match. Please try again.!"})

    send_resp(conn, 404, body)
  end

  def call(conn, {:error, :no_data}) do
    body = Poison.encode!(%{error: "Please provide all necessary datas to login.!"})
    send_resp(conn, 400, body)
  end

  def call(conn, {:error, :no_permission}) do
    body = Poison.encode!(%{error: "You are not authorized for this action.!"})
    send_resp(conn, 400, body)
  end

  def call(conn, {:error, :expired}) do
    body = Poison.encode!(%{error: "Expired.!"})
    send_resp(conn, 400, body)
  end

  def call(conn, {:error, :already_member}) do
    body = Poison.encode!(%{error: "User with this email exists.!"})
    send_resp(conn, 422, body)
  end

  def call(conn, {:error, :wrong_flow}) do
    body = Poison.encode!(%{error: "This instance follow a different flow.!"})
    send_resp(conn, 422, body)
  end

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(WraftDocWeb.ErrorView, :"404")
  end
end
