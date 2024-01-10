defmodule WraftDocWeb.Auth.CurrentUserTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias Guardian.Plug.EnsureAuthenticated
  alias Guardian.Plug.LoadResource
  alias Guardian.Plug.VerifyHeader
  alias WraftDocWeb.CurrentUser
  alias WraftDocWeb.Guardian
  alias WraftDocWeb.Guardian.AuthErrorHandler

  test "assigns `current_user` in conn" do
    user = insert(:user_with_organisation)

    {:ok, token, _claims} =
      Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

    conn =
      token
      |> conn_init()
      |> CurrentUser.call([])

    assert conn.assigns[:current_user].id == user.id
    refute conn.halted
  end

  test "return 404 if the user does not exist" do
    user = build(:user)

    {:ok, token, _claims} =
      Guardian.encode_and_sign(user, %{organisation_id: Ecto.UUID.generate()})

    conn =
      token
      |> conn_init()
      |> CurrentUser.call([])

    assert conn.assigns[:current_user] == nil
    assert json_response(conn, 404)["errors"] == "No user found"
    assert conn.halted
  end

  # Private
  defp conn_init(token) do
    opts = [module: WraftDocWeb.Guardian, error_handler: AuthErrorHandler]

    build_conn()
    |> put_req_header("authorization", token)
    |> put_resp_content_type("application/json")
    |> VerifyHeader.call(opts)
    |> EnsureAuthenticated.call(opts)
    |> LoadResource.call(opts)
  end
end
