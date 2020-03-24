defmodule WraftDocWeb.FlowControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Flow, Repo}

  @valid_attrs %{
    name: "Authorised",
    organisation_id: 12
  }

  @invalid_attrs %{}
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

  test "create flow by valid attrrs", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Flow |> Repo.all() |> length()
    %{uuid: organisation_id} = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation_id)

    conn =
      post(
        conn,
        Routes.v1_flow_path(conn, :create, params)
      )
      |> doc(operation_id: "create_flow")

    assert count_before + 1 == Flow |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  test "does not create flow by invalid attrs", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Flow |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_flow_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_flow")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Flow |> Repo.all() |> length()
  end

  test "update flow on valid attributes", %{conn: conn} do
    flow = insert(:flow, creator: conn.assigns.current_user)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Flow |> Repo.all() |> length()
    %{id: organisation_id} = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation_id)

    conn =
      put(conn, Routes.v1_flow_path(conn, :update, flow.uuid, params))
      |> doc(operation_id: "update_flow")

    assert json_response(conn, 200)["flow"]["name"] == @valid_attrs.name
    assert count_before == Flow |> Repo.all() |> length()
  end

  test "does't update flow on invalid attrs", %{conn: conn} do
    flow = insert(:flow, creator: conn.assigns.current_user)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_flow_path(conn, :update, flow.uuid, @invalid_attrs))
      |> doc(operation_id: "update_flow")

    assert json_response(conn, 422)["errors"]["flow_id"] == ["can't be blank"]
  end

  test "index lists flow by current user", %{conn: conn} do
    user = conn.assigns.current_user

    f1 = insert(:flow, creator: user, organisation: user.organisation)
    f2 = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_flow_path(conn, :index))

    flow_index = json_response(conn, 200)["flows"]
    flow = Enum.map(flow_index, fn %{"flow" => %{"name" => name}} -> name end)
    assert List.to_string(flow) =~ f1.name
    assert List.to_string(flow) =~ f2.name
  end

  test "show renders flow details by id", %{conn: conn} do
    flow = insert(:flow, creator: conn.assigns.current_user)

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_flow_path(conn, :show, flow.uuid))

    assert json_response(conn, 200)["flow"]["name"] == flow.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_flow_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete flow by given id", %{conn: conn} do
    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    flow = insert(:flow, creator: conn.assigns.current_user)
    count_before = Flow |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_flow_path(conn, :delete, flow.uuid))
    assert count_before - 1 == Flow |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == flow.name
  end
end
