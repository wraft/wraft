defmodule WraftDocWeb.Plug.ValidMembershipCheckTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDocWeb.Plug.ValidMembershipCheck
  alias WraftDoc.Repo

  test "user is allowed to continue when user's organisation has a valid membership" do
    user = insert(:user)
    insert(:user_role, user: user)
    user = user |> Repo.preload(:roles)
    role_names = user.roles |> Enum.map(fn x -> x.name end)
    user = user |> Map.put(:role_names, role_names)
    insert(:membership, organisation: user.organisation)

    conn = assign(build_conn(), :current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is allowed to continue when user has admin role" do
    role = insert(:role, name: "super_admin")
    user = insert(:user)
    insert(:user_role, role: role, user: user)
    user = user |> Repo.preload(:roles)
    role_names = user.roles |> Enum.map(fn x -> x.name end)
    user = user |> Map.put(:role_names, role_names)

    conn = assign(build_conn(), :current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "user is blocked from accessing services when user's organisation does not have a valid membership" do
    user = insert(:user)
    insert(:user_role, user: user)
    user = user |> Repo.preload(:roles)
    role_names = user.roles |> Enum.map(fn x -> x.name end)
    user = user |> Map.put(:role_names, role_names)
    insert(:membership, is_expired: true, organisation: user.organisation)

    conn = assign(build_conn(), :current_user, user)
    returned_conn = ValidMembershipCheck.call(conn, %{})

    assert returned_conn.status == 400

    assert json_response(returned_conn, 400)["errors"] ==
             "You do not have a valid membership. Upgrade your membership to continue.!"
  end
end
