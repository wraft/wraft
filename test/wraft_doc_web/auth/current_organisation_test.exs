defmodule WraftDocWeb.Auth.CurrentOrganisationTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias Guardian.Plug.EnsureAuthenticated
  alias Guardian.Plug.LoadResource
  alias Guardian.Plug.VerifyHeader
  alias WraftDocWeb.CurrentOrganisation
  alias WraftDocWeb.CurrentUser
  alias WraftDocWeb.Guardian
  alias WraftDocWeb.Guardian.AuthErrorHandler

  test "assigns `current_organisation_id` in `current_user` in conn", %{conn: conn} do
    user = insert(:user_with_organisation)

    {:ok, token, _claims} =
      Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

    opts = [module: WraftDocWeb.Guardian, error_handler: AuthErrorHandler]

    conn =
      conn
      |> put_req_header("authorization", token)
      |> VerifyHeader.call(opts)
      |> EnsureAuthenticated.call(opts)
      |> LoadResource.call(opts)
      |> CurrentUser.call([])
      |> CurrentOrganisation.call([])

    assert conn.assigns[:current_user].current_org_id == user.current_org_id
    refute conn.halted
  end

  test "return 404 if the organisation does not exist", %{conn: conn} do
    user = insert(:user)

    {:ok, token, _claims} =
      Guardian.encode_and_sign(user, %{organisation_id: Ecto.UUID.generate()})

    opts = [module: WraftDocWeb.Guardian, error_handler: AuthErrorHandler]

    conn =
      conn
      |> put_req_header("authorization", token)
      |> put_resp_content_type("application/json")
      |> VerifyHeader.call(opts)
      |> EnsureAuthenticated.call(opts)
      |> LoadResource.call(opts)
      |> CurrentUser.call([])
      |> CurrentOrganisation.call([])

    assert conn.assigns[:current_user].current_org_id == nil
    assert json_response(conn, 404)["errors"] == "No organisation found"
    assert conn.halted
  end
end
