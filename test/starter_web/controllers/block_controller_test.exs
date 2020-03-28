defmodule BlockControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias WraftDoc.{Document.Block, Repo}
  @dataset "{
    type: 'pie',
    data: {

      datasets: [{
        label: 'Raisins',
        data: [12, 6, 5, 18, 12]
      }, {
        label: 'Bananas',
        data: [4, 8, 16, 5, 5]
      }]
    }
  }"

  @valid_attrs %{
    name: "energy consumption",
    btype: "pie",
    dataset: Poison.decode(@dataset)
  }
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

  test "create block by valid attributes", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Block |> Repo.all() |> length()

    conn = post(conn, Routes.v1_block_path(conn, :create, @valid_attrs))
    assert json_response(conn, 201)["btype"] == @valid_attrs.btype
    assert count_before + 1 == Block |> Repo.all() |> length()
  end
end
