defmodule WraftDocWeb.Auth.CurrentUserTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias Guardian.Plug
  alias WraftDocWeb.CurrentUser
  alias WraftDocWeb.Guardian

  describe "call/2" do
    test "assigns `current_user` in conn when user exists" do
      user = insert(:user_with_organisation)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        token
        |> conn_init()
        |> CurrentUser.call([])

      assert conn.assigns[:current_user].id == user.id
      assert conn.assigns[:current_user].email == user.email
      refute conn.halted
    end

    test "preloads user profile and instances_to_approve" do
      user = insert(:user_with_organisation)
      insert(:profile, user: user)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        token
        |> conn_init()
        |> CurrentUser.call([])

      assert conn.assigns[:current_user].profile != nil
      assert Ecto.assoc_loaded?(conn.assigns[:current_user].profile)
      assert Ecto.assoc_loaded?(conn.assigns[:current_user].instances_to_approve)
      refute conn.halted
    end

    test "returns 404 if the user does not exist" do
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

    test "skips processing when current_user is already assigned" do
      user = insert(:user_with_organisation)
      existing_user = insert(:user_with_organisation)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        token
        |> conn_init()
        |> assign(:current_user, existing_user)
        |> CurrentUser.call([])

      # Should keep the existing user, not replace it
      assert conn.assigns[:current_user].id == existing_user.id
      assert conn.assigns[:current_user].id != user.id
      refute conn.halted
    end

    test "adds auth_type to params when claims contain type" do
      user = insert(:user_with_organisation)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{
          organisation_id: user.current_org_id,
          type: "api_key"
        })

      conn =
        token
        |> conn_init()
        |> CurrentUser.call([])

      assert conn.params["auth_type"] == "api_key"
      assert conn.assigns[:current_user].id == user.id
      refute conn.halted
    end

    test "does not add auth_type to params when claims do not contain type" do
      user = insert(:user_with_organisation)

      {:ok, token, _claims} =
        Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        token
        |> conn_init()
        |> CurrentUser.call([])

      refute Map.has_key?(conn.params, "auth_type")
      assert conn.assigns[:current_user].id == user.id
      refute conn.halted
    end

    test "does not halt when no JWT token is provided" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_resp_content_type("application/json")
        |> Map.put(:params, %{})
        |> CurrentUser.call([])

      refute Map.has_key?(conn.assigns, :current_user)
      refute conn.halted
    end

    test "does not halt when claims are nil" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> put_resp_content_type("application/json")
        |> Map.put(:params, %{})
        |> Plug.put_current_claims(nil)
        |> Plug.put_current_resource(nil)
        |> CurrentUser.call([])

      refute Map.has_key?(conn.assigns, :current_user)
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
  end
end
