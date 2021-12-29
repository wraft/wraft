defmodule WraftDocWeb.ApprovalSystemControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.ApprovalSystem, Repo}
  @name "Review by VC"
  @updated_name "Final review"
  @invalid_attrs %{pre_state_id: nil}
  setup %{conn: conn} do
    role = insert(:role, name: "super_admin")
    user = insert(:user)
    insert(:user_role, role: role, user: user)

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

  test "create approval_systems by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    current_user = conn.assigns.current_user

    flow = insert(:flow, organisation: current_user.organisation)
    pre_state = insert(:state, creator: current_user, organisation: current_user.organisation)
    post_state = insert(:state, creator: current_user, organisation: current_user.organisation)
    approver = insert(:user, organisation: current_user.organisation)

    params = %{
      flow_id: flow.id,
      pre_state_id: pre_state.id,
      post_state_id: post_state.id,
      approver_id: approver.id,
      name: @name
    }

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_approval_system_path(conn, :create, params))
      |> doc(operation_id: "create_resource")

    assert json_response(conn, 200)["approval_system"]["name"] == @name
    assert count_before + 1 == ApprovalSystem |> Repo.all() |> length()
  end

  test "does not create approval_systems by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn = post(conn, Routes.v1_approval_system_path(conn, :create, @invalid_attrs))

    assert json_response(conn, 422)["errors"]["pre_state_id"] == ["can't be blank"]
    assert count_before == ApprovalSystem |> Repo.all() |> length()
  end

  test "update approval_systems on valid attributes", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    current_user = conn.assigns.current_user

    organisation = current_user.organisation
    pre_state = insert(:state, creator: current_user, organisation: organisation)
    post_state = insert(:state, creator: current_user, organisation: organisation)
    flow = insert(:flow, organisation: current_user.organisation)
    approver = insert(:user, organisation: current_user.organisation)

    params = %{
      pre_state_id: pre_state.id,
      post_state_id: post_state.id,
      approver_id: approver.id,
      name: @updated_name
    }

    approval_system =
      insert(:approval_system,
        pre_state: pre_state,
        post_state: post_state,
        flow: flow
      )

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn = put(conn, Routes.v1_approval_system_path(conn, :update, approval_system.id, params))

    assert json_response(conn, 200)["approval_system"]["name"] == @updated_name
    assert count_before == ApprovalSystem |> Repo.all() |> length()
  end

  test "does't update approval_systems for invalid attrs", %{conn: conn} do
    current_user = conn.assigns.current_user
    organisation = current_user.organisation
    pre_state = insert(:state, creator: current_user, organisation: organisation)
    post_state = insert(:state, creator: current_user, organisation: organisation)
    flow = insert(:flow, organisation: current_user.organisation)
    _approver = insert(:user, organisation: current_user.organisation)

    approval_system =
      insert(:approval_system,
        pre_state: pre_state,
        post_state: post_state,
        flow: flow,
        name: @name
      )

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_approval_system_path(conn, :update, approval_system.id, @invalid_attrs))

    assert json_response(conn, 422)["errors"]["pre_state_id"] == ["can't be blank"]
  end

  test "show renders approval_system details by id", %{conn: conn} do
    user = conn.assigns.current_user
    organisation = user.organisation
    flow = insert(:flow, organisation: organisation)

    pre_state = insert(:state, creator: user, organisation: organisation)
    post_state = insert(:state, creator: user, organisation: organisation)

    approval_system =
      insert(:approval_system,
        flow: flow,
        creator: user,
        pre_state: pre_state,
        post_state: post_state,
        approver: user,
        name: @name
      )

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_approval_system_path(conn, :show, approval_system.id))

    assert json_response(conn, 200)["approval_system"]["name"] == @name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_approval_system_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The ApprovalSystem id does not exist..!"
  end

  test "delete approval_system by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    organisation = user.organisation
    pre_state = insert(:state, creator: user, organisation: organisation)
    post_state = insert(:state, creator: user, organisation: organisation)
    flow = insert(:flow, organisation: user.organisation)
    _approver = insert(:user, organisation: user.organisation)

    approval_system =
      insert(:approval_system,
        pre_state: pre_state,
        post_state: post_state,
        flow: flow,
        name: @name
      )

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_approval_system_path(conn, :delete, approval_system.id))
    assert count_before - 1 == ApprovalSystem |> Repo.all() |> length()
    assert json_response(conn, 200)["approval_system"]["name"] == approval_system.name
  end

  # test "approve a system renders updated state and status", %{conn: conn} do
  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   user = conn.assigns.current_user
  #   organisation = user.organisation
  #   content_type = insert(:content_type, creator: user, organisation: user.organisation)
  #   current_user = conn.assigns.current_user
  #   state = insert(:state, creator: user, organisation: user.organisation)
  #   instance = insert(:instance, state: state, creator: current_user, content_type: content_type)

  #   approval_system =
  #     insert(:approval_system,
  #       approver: current_user,
  #       user: current_user,
  #       instance: instance,
  #       pre_state: state,
  #       user: user,
  #       organisation: organisation
  #     )

  #   conn = post(conn, Routes.v1_approval_system_path(conn, :approve, approval_system.id))
  #   assert json_response(conn, 200)["approved"] == true
  # end

  # test "error not found on user from another organsiation", %{conn: conn} do
  #   user = insert(:user)
  #   organisation = user.organisation
  #   approval_system = insert(:approval_system, organisation: organisation, user: user)

  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   conn = get(conn, Routes.v1_approval_system_path(conn, :show, approval_system.id))

  #   assert json_response(conn, 404) == "Not Found"
  # end

  describe "index/2" do
    test "lists all approval systems in organisation", %{conn: conn} do
      user = conn.assigns.current_user
      flow = insert(:flow, creator: user, organisation: user.organisation)
      s1 = insert(:state, order: 1, flow: flow)
      s2 = insert(:state, order: 2, flow: flow)

      insert(:approval_system,
        pre_state: s1,
        post_state: s2,
        approver: user,
        flow: flow
      )

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_approval_system_path(conn, :index), page: 1)

      approval_systems =
        conn
        |> json_response(200)
        |> get_in(["approval_systems"])
        |> Enum.map(fn x -> x["pre_state"]["state"] end)

      assert to_string(approval_systems) =~ s1.state
    end
  end
end
