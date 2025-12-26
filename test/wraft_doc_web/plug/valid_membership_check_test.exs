defmodule WraftDocWeb.Plug.ValidMembershipCheckTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDocWeb.Plug.ValidMembershipCheck

  describe "call/2" do
    test "user is allowed to continue when user's organisation has a valid membership", %{
      conn: conn
    } do
      returned_conn = ValidMembershipCheck.call(conn, %{})

      # Check important properties instead of struct equality
      assert returned_conn.assigns.current_user.id == conn.assigns.current_user.id
      assert returned_conn.status != 400
      refute returned_conn.halted
    end

    @tag :skip
    test "user is allowed to continue when current organisation is personal organisation even if membership is expired" do
      user = insert(:user_with_personal_organisation)
      insert(:membership, is_expired: true, organisation: List.first(user.owned_organisations))

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> Plug.Conn.assign(:current_user, user)

      returned_conn = ValidMembershipCheck.call(conn, %{})

      # Check important properties instead of struct equality
      assert returned_conn.assigns.current_user.id == conn.assigns.current_user.id
      assert returned_conn.status != 400
      refute returned_conn.halted
    end

    test "user is blocked from accessing services when user's organisation does not have a valid membership" do
      organisation = insert(:organisation)
      insert(:membership, is_expired: true, organisation: organisation)
      user = insert(:user, current_org_id: organisation.id)

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id})

      conn =
        build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer " <> token)
        |> assign(:current_user, user)

      returned_conn = ValidMembershipCheck.call(conn, %{})

      assert returned_conn.status == 400
      assert returned_conn.halted

      assert json_response(returned_conn, 400)["errors"] ==
               "You do not have a valid subscription. Upgrade your subscription to continue.!"
    end

    test "bypasses check when auth_type is present in params" do
      organisation = insert(:organisation)
      insert(:membership, is_expired: true, organisation: organisation)
      user = insert(:user, current_org_id: organisation.id)

      {:ok, token, _} =
        WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: organisation.id})

      conn =
        build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer " <> token)
        |> assign(:current_user, user)
        |> Map.put(:params, %{"auth_type" => "api_key"})

      returned_conn = ValidMembershipCheck.call(conn, %{})

      # Check important properties instead of struct equality
      assert returned_conn.assigns.current_user.id == conn.assigns.current_user.id
      assert returned_conn.status != 400
      refute returned_conn.halted
    end

    test "returns error response with correct content type and status" do
      organisation = insert(:organisation)
      insert(:membership, is_expired: true, organisation: organisation)
      user = insert(:user, current_org_id: organisation.id)

      conn =
        build_conn()
        |> Plug.Conn.put_req_header("accept", "application/json")
        |> assign(:current_user, user)

      returned_conn = ValidMembershipCheck.call(conn, %{})

      assert returned_conn.status == 400
      assert returned_conn.halted
      assert get_resp_header(returned_conn, "content-type") == ["application/json; charset=utf-8"]

      response = json_response(returned_conn, 400)

      assert response["errors"] ==
               "You do not have a valid subscription. Upgrade your subscription to continue.!"
    end
  end
end
