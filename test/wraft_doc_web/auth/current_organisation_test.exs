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

  test "assigns `current_org_id`,`role_names` and `permissions` in `current_user` in conn" do
    user = insert(:user_with_organisation)
    permissions = ["layout:index", "layout:show", "layout:create", "layout:update"]

    role =
      insert(:role,
        name: "custom role",
        permissions: permissions,
        organisation: List.first(user.owned_organisations)
      )

    insert(:user_role, user: user, role: role)

    {:ok, token, _claims} =
      Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

    conn =
      token
      |> conn_init()
      |> CurrentOrganisation.call([])

    assert conn.assigns[:current_user].current_org_id == user.current_org_id
    assert conn.assigns[:current_user].permissions == permissions
    assert conn.assigns[:current_user].role_names == [role.name]
    refute conn.halted
  end

  test "return 404 if the organisation does not exist" do
    user = insert(:user)

    {:ok, token, _claims} =
      Guardian.encode_and_sign(user, %{organisation_id: Ecto.UUID.generate()})

    conn =
      token
      |> conn_init()
      |> CurrentOrganisation.call([])

    assert conn.assigns[:current_user].current_org_id == nil
    assert json_response(conn, 404)["errors"] == "No organisation found"
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
    |> CurrentUser.call([])
  end
end
