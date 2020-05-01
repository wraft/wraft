defmodule WraftDocWeb.Api.V1.EngineControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  setup %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  test "index lists engines from database", %{conn: conn} do
    e1 = insert(:engine)
    e2 = insert(:engine)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_engine_path(conn, :index))
    engine_index = json_response(conn, 200)["engines"]
    engine = Enum.map(engine_index, fn %{"name" => name} -> name end)
    assert List.to_string(engine) =~ e1.name
    assert List.to_string(engine) =~ e2.name
  end
end
