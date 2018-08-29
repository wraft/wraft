defmodule StarterWeb.FallbackController do
     @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use StarterWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
      conn
      |> put_status(:unprocessable_entity)
      |> render(StarterWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(StarterWeb.ErrorView, :"404")
  end
end