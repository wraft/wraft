defmodule WraftDocWeb.Api.V1.StateControllerTest do
  @moduledoc """
  Test module for state controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.Flow.State, Repo}

  @valid_attrs %{
    state: "Published",
    order: 1
  }

  @invalid_attrs %{state: ""}

  test "create states by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

    count_before = State |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_state_path(conn, :create, flow.id), @valid_attrs)
      |> doc(operation_id: "create_state")

    assert count_before + 1 == State |> Repo.all() |> length()
    assert json_response(conn, 200)["state"] == @valid_attrs.state
  end

  test "does not create states by invalid attrs", %{conn: conn} do
    user = conn.assigns[:current_user]
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

    count_before = State |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_state_path(conn, :create, flow.id), @invalid_attrs)
      |> doc(operation_id: "create_state")

    assert json_response(conn, 422)["errors"]["state"] == ["can't be blank"]
    assert count_before == State |> Repo.all() |> length()
  end

  test "update states on valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    state = insert(:state, organisation: List.first(user.owned_organisations))

    count_before = State |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_state_path(conn, :update, state.id, @valid_attrs))
      |> doc(operation_id: "update_state")

    assert json_response(conn, 200)["state"]["order"] == @valid_attrs.order
    assert json_response(conn, 200)["state"]["state"] == @valid_attrs.state
    assert count_before == State |> Repo.all() |> length()
  end

  test "does't update states for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    state = insert(:state, organisation: List.first(user.owned_organisations))

    conn =
      conn
      |> put(Routes.v1_state_path(conn, :update, state.id, @invalid_attrs))
      |> doc(operation_id: "update_state")

    assert json_response(conn, 422)["errors"]["state"] == ["can't be blank"]
  end

  test "index lists states by current user", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow)
    [organisation] = user.owned_organisations

    a1 = insert(:state, creator: user, organisation: organisation, flow: flow)
    a2 = insert(:state, creator: user, organisation: organisation, flow: flow)

    conn = get(conn, Routes.v1_state_path(conn, :index, flow.id))
    states_index = json_response(conn, 200)["states"]
    states = Enum.map(states_index, fn %{"state" => state} -> state["state"] end)
    assert List.to_string(states) =~ a1.state
    assert List.to_string(states) =~ a2.state
  end

  test "delete state by given id", %{conn: conn} do
    user = conn.assigns[:current_user]
    state = insert(:state, organisation: List.first(user.owned_organisations))
    count_before = State |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_state_path(conn, :delete, state.id))
    assert count_before - 1 == State |> Repo.all() |> length()
    assert json_response(conn, 200)["state"] == state.state
  end

  test "error not found for user from another organisation", %{conn: conn} do
    state = insert(:state)
    conn = delete(conn, Routes.v1_state_path(conn, :delete, state.id))
    assert json_response(conn, 400)["errors"] == "The id does not exist..!"
  end
end
