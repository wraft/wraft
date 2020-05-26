defmodule WraftDocWeb.Api.V1.StateControllerTest do
  @moduledoc """
  Test module for state controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Flow.State, Repo}

  @valid_attrs %{
    state: "Published",
    order: 1
  }

  @invalid_attrs %{state: ""}
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

  test "create states by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = State |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_state_path(conn, :create, flow.uuid), @valid_attrs)
      |> doc(operation_id: "create_state")

    assert count_before + 1 == State |> Repo.all() |> length()
    assert json_response(conn, 200)["state"] == @valid_attrs.state
  end

  test "does not create states by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    flow = insert(:flow, creator: user, organisation: user.organisation)

    count_before = State |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_state_path(conn, :create, flow.uuid), @invalid_attrs)
      |> doc(operation_id: "create_state")

    assert json_response(conn, 422)["errors"]["state"] == ["can't be blank"]
    assert count_before == State |> Repo.all() |> length()
  end

  test "update states on valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    state = insert(:state, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = State |> Repo.all() |> length()

    conn =
      put(conn, Routes.v1_state_path(conn, :update, state.uuid, @valid_attrs))
      |> doc(operation_id: "update_state")

    assert json_response(conn, 200)["state"]["order"] == @valid_attrs.order
    assert json_response(conn, 200)["state"]["state"] == @valid_attrs.state
    assert count_before == State |> Repo.all() |> length()
  end

  test "does't update states for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    state = insert(:state, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_state_path(conn, :update, state.uuid, @invalid_attrs))
      |> doc(operation_id: "update_state")

    assert json_response(conn, 422)["errors"]["state"] == ["can't be blank"]
  end

  test "index lists states by current user", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow)

    a1 = insert(:state, creator: user, organisation: user.organisation, flow: flow)
    a2 = insert(:state, creator: user, organisation: user.organisation, flow: flow)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_state_path(conn, :index, flow.uuid))
    states_index = json_response(conn, 200)["states"]
    states = Enum.map(states_index, fn %{"state" => state} -> state["state"] end)
    assert List.to_string(states) =~ a1.state
    assert List.to_string(states) =~ a2.state
  end

  test "delete state by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    state = insert(:state, organisation: user.organisation)
    count_before = State |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_state_path(conn, :delete, state.uuid))
    assert count_before - 1 == State |> Repo.all() |> length()
    assert json_response(conn, 200)["state"] == state.state
  end

  test "error not found for user from another organisation", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = insert(:user)
    state = insert(:state, creator: user, organisation: user.organisation)

    conn = delete(conn, Routes.v1_state_path(conn, :delete, state.uuid))
    assert json_response(conn, 404) == "Not Found"
  end
end