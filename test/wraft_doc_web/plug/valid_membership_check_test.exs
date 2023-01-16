defmodule WraftDocWeb.Plug.ValidMembershipCheckTest do
  @moduledoc false
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.Repo
  alias WraftDocWeb.Plug.ValidMembershipCheck

  test "user is allowed to continue when user's organisation has a valid membership", %{
    conn: conn
  } do
    user = insert(:user)
    insert(:user_role, user: user)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    insert(:membership, organisation: user.organisation)

    conn = assign(conn, :current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is allowed to continue when current organisation is personal organisation even if membership is expired",
       %{conn: conn} do
    organisation = insert(:organisation, name: "Personal")
    user = insert(:user, organisation: organisation, current_org_id: organisation.id)
    insert(:user_role, user: user)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    insert(:membership, is_expired: true, organisation: user.organisation)

    conn = assign(conn, :current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is blocked from accessing services when user's organisation does not have a valid membership",
       %{conn: conn} do
    user = insert(:user)
    insert(:user_role, user: user)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    insert(:membership, is_expired: true, organisation: user.organisation)

    conn = assign(conn, :current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn.status == 400

    assert json_response(returned_conn, 400)["errors"] ==
             "You do not have a valid membership. Upgrade your membership to continue.!"
  end
end
