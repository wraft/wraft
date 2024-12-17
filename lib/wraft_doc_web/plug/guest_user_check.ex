defmodule WraftDocWeb.Plug.GuestUserCheck do
  @moduledoc """
  Plug to check if the current user is a guest user.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{req_headers: [_ | _]} = conn, _params) do
    halt(conn)

    # with {:ok, %{email: email}} <- AuthTokens.check_token(token, :document_invite),
    #      %User{is_guest: true} = user <- Account.get_user_by_email(email) do
    #   conn = put_private(conn, :type, "guest")
    #   assign(conn, :current_user, user)
    # else
    #   {:error, :invalid_token} ->
    #     AuthErrorHandler.auth_error(conn, {:error, :invalid_token})
    # end
  end

  def call(conn, _params) do
    body =
      Jason.encode!(%{
        errors: "Token does not exist!"
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, body)
    |> halt()
  end
end
