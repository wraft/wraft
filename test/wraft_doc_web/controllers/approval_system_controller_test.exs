defmodule WraftDocWeb.ApprovalSystemControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Enterprise.ApprovalSystem, Repo}

  @invalid_attrs %{instance_id: nil, pre_state_id: nil}
  setup %{conn: conn} do
    role = insert(:role, name: "admin")
    user = insert(:user, role: role)

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

    content_type =
      insert(:content_type, creator: current_user, organisation: current_user.organisation)

    instance = insert(:instance, creator: current_user, content_type: content_type)
    pre_state = insert(:state, creator: current_user, organisation: current_user.organisation)
    post_state = insert(:state, creator: current_user, organisation: current_user.organisation)
    approver = insert(:user)

    params = %{
      instance_id: instance.uuid,
      pre_state_id: pre_state.uuid,
      post_state_id: post_state.uuid,
      approver_id: approver.uuid
    }

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_approval_system_path(conn, :create, params))
      |> doc(operation_id: "create_resource")

    assert count_before + 1 == ApprovalSystem |> Repo.all() |> length()
    assert json_response(conn, 200)["instance"]["id"] == instance.uuid
  end

  test "does not create approval_systems by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_approval_system_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_resource")

    assert json_response(conn, 422)["errors"]["instance_id"] == ["can't be blank"]
    assert count_before == ApprovalSystem |> Repo.all() |> length()
  end

  test "update approval_systems on valid attributes", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    current_user = conn.assigns.current_user

    organisation = current_user.organisation
    content_type = insert(:content_type, creator: current_user, organisation: organisation)
    instance = insert(:instance, creator: current_user, content_type: content_type)
    pre_state = insert(:state, creator: current_user, organisation: organisation)
    post_state = insert(:state, creator: current_user, organisation: organisation)

    approver = insert(:user)

    params = %{
      instance_id: instance.uuid,
      pre_state_id: pre_state.uuid,
      post_state_id: post_state.uuid,
      approver_id: approver.uuid
    }

    approval_system =
      insert(:approval_system,
        instance: instance,
        pre_state: pre_state,
        post_state: post_state,
        user: current_user,
        organisation: organisation
      )

    count_before = ApprovalSystem |> Repo.all() |> length()

    conn =
      put(conn, Routes.v1_approval_system_path(conn, :update, approval_system.uuid, params))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 200)["instance"]["id"] == instance.uuid
    assert count_before == ApprovalSystem |> Repo.all() |> length()
  end

  test "does't update approval_systems for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    organisation = user.organisation
    approval_system = insert(:approval_system, organisation: organisation, user: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(
        conn,
        Routes.v1_approval_system_path(conn, :update, approval_system.uuid, @invalid_attrs)
      )
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 422)["errors"]["instance_id"] == ["can't be blank"]
  end

  test "show renders approval_system details by id", %{conn: conn} do
    user = conn.assigns.current_user
    organisation = user.organisation
    approval_system = insert(:approval_system, organisation: organisation, user: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_approval_system_path(conn, :show, approval_system.uuid))

    assert json_response(conn, 200)["instance"]["id"] == approval_system.instance.uuid
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_approval_system_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete approval_system by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    current_user = conn.assigns.current_user
    organisation = current_user.organisation
    approval_system = insert(:approval_system, user: current_user, organisation: organisation)
    count_before = ApprovalSystem |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_approval_system_path(conn, :delete, approval_system.uuid))
    assert count_before - 1 == ApprovalSystem |> Repo.all() |> length()
    assert json_response(conn, 200)["instance"]["id"] == approval_system.instance.uuid
  end

  test "approve a system renders updated state and status", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    organisation = user.organisation
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    current_user = conn.assigns.current_user
    state = insert(:state, creator: user, organisation: user.organisation)
    instance = insert(:instance, state: state, creator: current_user, content_type: content_type)

    approval_system =
      insert(:approval_system,
        approver: current_user,
        user: current_user,
        instance: instance,
        pre_state: state,
        user: user,
        organisation: organisation
      )

    conn = post(conn, Routes.v1_approval_system_path(conn, :approve), id: approval_system.uuid)
    assert json_response(conn, 200)["approved"] == true
  end

  test "error not found on user from another organsiation", %{conn: conn} do
    user = insert(:user)
    organisation = user.organisation
    approval_system = insert(:approval_system, organisation: organisation, user: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_approval_system_path(conn, :show, approval_system.uuid))

    assert json_response(conn, 404) == "Not Found"
  end
end
