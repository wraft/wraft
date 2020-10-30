defmodule WraftDocWeb.Plug.ValidMembershipCheckTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDocWeb.Plug.ValidMembershipCheck
  alias WraftDoc.Repo

  test "user is allowed to continue when user's organisation has a valid membership" do
    user = insert(:user)
    membership = insert(:membership, organisation: user.organisation)

    conn = build_conn() |> assign(:current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is allowed to continue when user has admin role" do
    role = insert(:role, name: "admin")
    user = insert(:user, role: role)

    conn = build_conn() |> assign(:current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is blocked from accessing services when user's organisation does not have a valid membership" do
    user = insert(:user)
    membership = insert(:membership, is_expired: true, organisation: user.organisation)

    conn = build_conn() |> assign(:current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn.status == 400

    assert json_response(returned_conn, 400)["errors"] ==
             "You do not have a valid membership. Upgrade your membership to continue.!"
  end
end