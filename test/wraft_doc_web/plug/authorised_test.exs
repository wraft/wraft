defmodule WraftDocWeb.Plug.AuthorizedTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.Repo
  alias WraftDocWeb.Plug.Authorized

  describe "call/2" do
    test "allows guest paths without checking permissions" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> Map.put(:path_info, ["api", "v1", "guest", "documents"])

      returned_conn = Authorized.call(conn, %{})

      assert returned_conn == conn
      refute returned_conn.halted
    end

    test "allows if user is superadmin" do
      user = %{role_names: ["superadmin"], permissions: []}
      conn = assign(build_conn(), :current_user, user)
      conn = merge_private(conn, phoenix_action: :create)
      opts = [create: "members:manage"]

      returned_conn = Authorized.call(conn, opts)

      assert returned_conn == conn
      refute returned_conn.halted
    end

    test "allows if action does not require permission" do
      user = %{role_names: [], permissions: []}
      conn = assign(build_conn(), :current_user, user)
      conn = merge_private(conn, phoenix_action: :index)
      opts = [create: "perm"]

      returned_conn = Authorized.call(conn, opts)

      assert returned_conn == conn
      refute returned_conn.halted
    end

    test "allows if user has required permission" do
      user = %{role_names: [], permissions: ["members:manage"]}
      conn = assign(build_conn(), :current_user, user)
      conn = merge_private(conn, phoenix_action: :create)
      opts = [create: "members:manage"]

      returned_conn = Authorized.call(conn, opts)

      assert returned_conn == conn
      refute returned_conn.halted
    end

    test "denies if user lacks required permission" do
      user = %{role_names: [], permissions: ["other:perm"]}
      conn = assign(build_conn(), :current_user, user)
      conn = merge_private(conn, phoenix_action: :create)
      opts = [create: "members:manage"]

      returned_conn = Authorized.call(conn, opts)

      assert returned_conn.status == 403
      assert returned_conn.halted
      assert Jason.decode!(returned_conn.resp_body) == %{"errors" => "Unauthorized access.!"}
    end
  end
end
