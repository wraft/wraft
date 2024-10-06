defmodule WraftDocWeb.Api.V1.FlowControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Repo

  @valid_attrs %{
    name: "Authorised",
    organisation_id: 12
  }

  @invalid_attrs %{name: ""}

  test "create flow by valid attrrs and creates default state", %{conn: conn} do
    state_count_before = State |> Repo.all() |> length()
    count_before = Flow |> Repo.all() |> length()
    %{id: organisation_id} = insert(:organisation)
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
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

    count_before = Flow |> Repo.all() |> length()
    %{id: organisation_id} = insert(:organisation)
    params = Map.put(@valid_attrs, :organisation_id, organisation_id)

    conn =
      conn
      |> put(Routes.v1_flow_path(conn, :update, flow.id, params))
      |> doc(operation_id: "update_flow")

    assert json_response(conn, 200)["flow"]["name"] == @valid_attrs.name
    assert count_before == Flow |> Repo.all() |> length()
  end

  test "does't update flow on invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

    conn =
      conn
      |> put(Routes.v1_flow_path(conn, :update, flow.id, @invalid_attrs))
      |> doc(operation_id: "update_flow")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
  end

  test "index lists flow by current user", %{conn: conn} do
    user = conn.assigns.current_user
    [organisation] = user.owned_organisations
    f1 = insert(:flow, creator: user, organisation: organisation)
    f2 = insert(:flow, creator: user, organisation: organisation)

    conn = get(conn, Routes.v1_flow_path(conn, :index))

    flow_index = json_response(conn, 200)["flows"]
    flow = Enum.map(flow_index, fn %{"flow" => %{"name" => name}} -> name end)
    assert List.to_string(flow) =~ f1.name
    assert List.to_string(flow) =~ f2.name
  end

  test "show renders flow details by id", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

    conn = get(conn, Routes.v1_flow_path(conn, :show, flow.id))

    assert json_response(conn, 200)["flow"]["name"] == flow.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn = get(conn, Routes.v1_flow_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The Flow id does not exist..!"
  end

  test "delete flow by given id", %{conn: conn} do
    user = conn.assigns.current_user
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))
    count_before = Flow |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_flow_path(conn, :delete, flow.id))
    assert count_before - 1 == Flow |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == flow.name
  end

  test "error not found for user from another organisation", %{conn: conn} do
    flow = insert(:flow)

    conn = get(conn, Routes.v1_flow_path(conn, :show, flow.id))

    assert json_response(conn, 400)["errors"] == "The Flow id does not exist..!"
  end

  describe "align_states/2" do
    # FIXME need to fix this
    test "align order of state under a flow ", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      flow = insert(:flow, creator: user, organisation: organisation)
      s1 = insert(:state, flow: flow, organisation: organisation, order: 1)
      s2 = insert(:state, flow: flow, organisation: organisation, order: 2)
      params = %{states: [%{id: s1.id, order: 2}, %{id: s2.id, order: 1}]}

      conn = put(conn, Routes.v1_flow_path(conn, :align_states, flow.id), params)

      state1_in_response =
        json_response(conn, 200)["states"]
        |> Enum.filter(fn x -> x["id"] == s1.id end)
        |> List.first()

      state2_in_response =
        json_response(conn, 200)["states"]
        |> Enum.filter(fn x -> x["id"] == s2.id end)
        |> List.first()

      assert state1_in_response["order"] == 2
      assert state2_in_response["order"] == 1
    end
  end
end
