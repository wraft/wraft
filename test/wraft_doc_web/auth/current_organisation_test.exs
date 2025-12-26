defmodule WraftDocWeb.Auth.CurrentOrganisationTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias Guardian.Plug
  alias WraftDoc.Repo
  alias WraftDocWeb.CurrentOrganisation
  alias WraftDocWeb.CurrentUser
  alias WraftDocWeb.Guardian

  # Setup shared mode for tests that may spawn async tasks (e.g., notifications)
  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  describe "call/2" do
    test "assigns `current_org_id`, `role_names` and `permissions` in `current_user` in conn" do
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

    test "aggregates permissions and role names when user has multiple roles" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      role1 =
        insert(:role,
          name: "role1",
          permissions: ["layout:index", "layout:show"],
          organisation: organisation
        )

      role2 =
        insert(:role,
          name: "role2",
          permissions: ["layout:create", "layout:update", "layout:index"],
          organisation: organisation
        )

      insert(:user_role, user: user, role: role1)
      insert(:user_role, user: user, role: role2)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        token
        |> conn_init()
        |> CurrentOrganisation.call([])

      assert conn.assigns[:current_user].current_org_id == user.current_org_id
      # Permissions should be unique and aggregated
      assert length(conn.assigns[:current_user].permissions) == 4
      assert "layout:index" in conn.assigns[:current_user].permissions
      assert "layout:show" in conn.assigns[:current_user].permissions
      assert "layout:create" in conn.assigns[:current_user].permissions
      assert "layout:update" in conn.assigns[:current_user].permissions
      # Role names should include both roles
      assert length(conn.assigns[:current_user].role_names) == 2
      assert role1.name in conn.assigns[:current_user].role_names
      assert role2.name in conn.assigns[:current_user].role_names
      refute conn.halted
    end

    test "assigns empty role_names and permissions when user has no roles" do
      user = insert(:user_with_organisation)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        token
        |> conn_init()
        |> CurrentOrganisation.call([])

      assert conn.assigns[:current_user].current_org_id == user.current_org_id
      assert conn.assigns[:current_user].permissions == []
      assert conn.assigns[:current_user].role_names == []
      refute conn.halted
    end

    test "returns 404 if the organisation does not exist" do
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

    test "skips processing when current_user already has org_id" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      # Pre-assign user with org_id
      user_with_org = Map.put(user, :current_org_id, organisation.id)

      conn =
        token
        |> conn_init()
        |> assign(:current_user, user_with_org)
        |> CurrentOrganisation.call([])

      # Should keep the existing org_id and not process JWT
      assert conn.assigns[:current_user].current_org_id == organisation.id
      refute conn.halted
    end

    test "sets org_id to nil when auth_type is present in params" do
      user = insert(:user_with_organisation)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id, type: "api_key"})

      conn =
        token
        |> conn_init()
        |> put_resp_content_type("application/json")
        |> Map.put(:params, %{"auth_type" => "api_key"})
        |> CurrentOrganisation.call([])

      assert conn.assigns[:current_user].current_org_id == nil
      refute conn.halted
    end

    test "only loads roles for the current organisation" do
      user = insert(:user_with_organisation)
      organisation1 = List.first(user.owned_organisations)
      organisation2 = insert(:organisation)

      role1 =
        insert(:role,
          name: "org1_role",
          permissions: ["layout:index"],
          organisation: organisation1
        )

      role2 =
        insert(:role,
          name: "org2_role",
          permissions: ["layout:show"],
          organisation: organisation2
        )

      insert(:user_role, user: user, role: role1)
      insert(:user_role, user: user, role: role2)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: organisation1.id})

      conn =
        token
        |> conn_init()
        |> CurrentOrganisation.call([])

      # Should only have role from organisation1
      assert conn.assigns[:current_user].current_org_id == organisation1.id
      assert conn.assigns[:current_user].role_names == [role1.name]
      assert conn.assigns[:current_user].permissions == ["layout:index"]
      refute role2.name in conn.assigns[:current_user].role_names
      refute "layout:show" in conn.assigns[:current_user].permissions
      refute conn.halted
    end
  end

  # Private
  defp conn_init(token) do
    {:ok, claims} = Guardian.decode_and_verify(token)

    build_conn()
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_resp_content_type("application/json")
    |> Map.put(:params, %{})
    |> Plug.put_current_claims(claims)
    |> Plug.put_current_resource(claims["sub"])
    |> CurrentUser.call([])
  end
end
