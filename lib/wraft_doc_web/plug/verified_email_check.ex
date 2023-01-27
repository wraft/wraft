defmodule WraftDocWeb.Plug.VerifiedEmailCheck do
  @moduledoc """
     Plug to check if user's email is verified.
  """
  import Ecto.Query
  import Plug.Conn

  alias WraftDoc.Account.User
  alias WraftDoc.Repo

  def init(_params) do
  end

  @spec call(Plug.Conn.t(), any) :: Plug.Conn.t()
  def call(conn, _params) do
    user = conn.assigns[:current_user]

    case get_email_verified_status(user) do
      true ->
        conn

      false ->
        body =
          Jason.encode!(%{
            errors: "Your email is not verified. Please verify your email!"
          })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, body)
        |> halt()
    end
  end

  defp get_email_verified_status(user) do
    query =
      from(u in User,
        where: u.email == ^user.email,
        select: u.email_verify
      )

    Repo.one(query)
  end
end
