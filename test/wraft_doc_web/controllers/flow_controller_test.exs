defmodule WraftDocWeb.Api.V1.FlowControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Flow, Enterprise.Flow.State, Repo}

  @valid_attrs %{
    name: "Authorised",
    organisation_id: 12
  }

  @invalid_attrs %{name: ""}
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

  test "create flow by valid attrrs and creates default state", %{conn: conn} do
    user = conn.assigns[:current_user]
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    state_count_before = State |> Repo.all() |> length()
    count_before = Flow |> Repo.all() |> length()
    %{uuid: organisation_id} = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation_id)

    conn =
      conn
      |> post(Routes.v1_flow_path(conn, :create, params))
      |> doc(operation_id: "create_flow")

    state_count_after = State |> Repo.all() |> length()

    assert count_before + 1 == Flow |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
    refute state_count_after == state_count_before
  end

  test "does not create flow by invalid attrs", %{conn: conn} do
    user = conn.assigns[:current_user]
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    count_before = Flow |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_flow_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_flow")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Flow |> Repo.all() |> length()
  end

  test "update flow on valid attributes", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Flow |> Repo.all() |> length()
    %{id: organisation_id} = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation_id)

    conn =
      conn
      |> put(Routes.v1_flow_path(conn, :update, flow.uuid, params))
      |> doc(operation_id: "update_flow")

    assert json_response(conn, 200)["flow"]["name"] == @valid_attrs.name
    assert count_before == Flow |> Repo.all() |> length()
  end

  test "does't update flow on invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      conn
      |> put(Routes.v1_flow_path(conn, :update, flow.uuid, @invalid_attrs))
      |> doc(operation_id: "update_flow")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
  end

  test "index lists flow by current user", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    f1 = insert(:flow, creator: user, organisation: user.organisation)
    f2 = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_flow_path(conn, :index))

    flow_index = json_response(conn, 200)["flows"]
    flow = Enum.map(flow_index, fn %{"flow" => %{"name" => name}} -> name end)
    assert List.to_string(flow) =~ f1.name
    assert List.to_string(flow) =~ f2.name
  end

  test "show renders flow details by id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_flow_path(conn, :show, flow.uuid))

    assert json_response(conn, 200)["flow"]["name"] == flow.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    user = conn.assigns[:current_user]
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn = get(conn, Routes.v1_flow_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete flow by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    count_before = Flow |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_flow_path(conn, :delete, flow.uuid))
    assert count_before - 1 == Flow |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == flow.name
  end

  test "error not found for user from another organisation", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:membership, organisation: current_user.organisation)
    user = insert(:user)
    flow = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, current_user)

    conn = get(conn, Routes.v1_flow_path(conn, :show, flow.uuid))

    assert json_response(conn, 404) == "Not Found"
  end
end
