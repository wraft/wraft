defmodule ExStarterWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use ExStarterWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(ExStarterWeb.ChangesetView, "error.json", changeset: changeset)
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

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(ExStarterWeb.ErrorView, :"404")
  end
end
