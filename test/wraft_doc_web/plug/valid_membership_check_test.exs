defmodule WraftDocWeb.Plug.ValidMembershipCheckTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDocWeb.Plug.ValidMembershipCheck

  test "user is allowed to continue when user's organisation has a valid membership", %{
    conn: conn
  } do
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is allowed to continue when current organisation is personal organisation even if membership is expired" do
    user = WraftDoc.Factory.insert(:user_with_personal_organisation)
    insert(:membership, is_expired: true, organisation: user.organisation)

    {:ok, token, _} =
      WraftDocWeb.Guardian.encode_and_sign(user, %{organisation_id: user.current_org_id})

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
      |> Plug.Conn.assign(:current_user, user)

    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
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

    assert json_response(returned_conn, 400)["errors"] ==
             "You do not have a valid membership. Upgrade your membership to continue.!"
  end
end
