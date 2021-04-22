defmodule WraftDocWeb.Api.V1.InstanceControllerTest do
  @moduledoc """
  Test module for instance controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Instance, Document.Instance.Version, Repo}

  @valid_attrs %{
    instance_id: "OFFL01",
    raw: "Content",
    serialized: %{title: "updated Title of the content", body: "updated Body of the content"}
  }
  @invalid_attrs %{raw: ""}

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

  test "create instances by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, organisation: user.organisation)
    state = insert(:state, organisation: user.organisation)
    vendor = insert(:vendor, organisation: user.organisation, creator: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    params = Map.merge(@valid_attrs, %{state_uuid: state.uuid, vendor_uuid: vendor.uuid})

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.uuid), params)
      |> doc(operation_id: "create_instance")

    assert json_response(conn, 200)["content"]["raw"] == @valid_attrs.raw
    assert count_before + 1 == Instance |> Repo.all() |> length()
  end

  test "does not create instances by invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, organisation: user.organisation)
    state = insert(:state, organisation: user.organisation)
    vendor = insert(:vendor, organisation: user.organisation, creator: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    count_before = Instance |> Repo.all() |> length()
    params = Map.merge(@invalid_attrs, %{state_uuid: state.uuid, vendor_uuid: vendor.uuid})

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.uuid), params)
      |> doc(operation_id: "create_instance")

    assert json_response(conn, 422)["errors"]["raw"] == ["can't be blank"]
    assert count_before == Instance |> Repo.all() |> length()
  end

  test "update instances on valid attributes", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    content_type = insert(:content_type)
    state = insert(:state)

    params =
      @valid_attrs |> Map.put(:content_type_id, content_type.uuid) |> Map.put(:state_id, state.id)

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_instance_path(conn, :update, instance.uuid, params))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 200)["content"]["raw"] == @valid_attrs.raw
    assert count_before == Instance |> Repo.all() |> length()
  end

  test "update instances creates instance version too", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    content_type = insert(:content_type)
    state = insert(:state)

    params =
      @valid_attrs |> Map.put(:content_type_id, content_type.uuid) |> Map.put(:state_id, state.id)

    version_count_before = Version |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_instance_path(conn, :update, instance.uuid, params))
      |> doc(operation_id: "update_asset")

    version_count_after = Version |> Repo.all() |> length()

    assert json_response(conn, 200)["content"]["raw"] == @valid_attrs.raw

    assert version_count_before + 1 == version_count_after
  end

  test "does't update instances for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      conn
      |> put(Routes.v1_instance_path(conn, :update, instance.uuid, @invalid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 422)["errors"]["raw"] == ["can't be blank"]
  end

  test "index lists all instances under a content type", %{conn: conn} do
    # u1 = insert(:user)
    # u2 = insert(:user)
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type)

    dt1 = insert(:instance, creator: user, content_type: content_type)
    dt2 = insert(:instance, creator: user, content_type: insert(:content_type))

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_instance_path(conn, :index, content_type.uuid))
    dt_index = json_response(conn, 200)["contents"]
    instances = Enum.map(dt_index, fn %{"content" => %{"raw" => raw}} -> raw end)
    assert List.to_string(instances) =~ dt1.raw
    assert List.to_string(instances) =~ dt2.raw
  end

  test "all templates lists all instances under an organisation", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    ct1 = insert(:content_type)
    ct2 = insert(:content_type)

    dt1 = insert(:instance, creator: user, content_type: ct1)
    dt2 = insert(:instance, creator: user, content_type: ct2)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_instance_path(conn, :all_contents))

    dt_index = json_response(conn, 200)["contents"]
    instances = Enum.map(dt_index, fn %{"content" => %{"raw" => raw}} -> raw end)
    assert List.to_string(instances) =~ dt1.raw
    assert List.to_string(instances) =~ dt2.raw
  end

  test "show renders instance details by id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_instance_path(conn, :show, instance.uuid))

    assert json_response(conn, 200)["content"]["raw"] == instance.raw
  end

  test "error not found for id does not exists", %{conn: conn} do
    user = conn.assigns[:current_user]
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn = get(conn, Routes.v1_instance_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete instance by given id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)
    count_before = Instance |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_instance_path(conn, :delete, instance.uuid))
    assert count_before - 1 == Instance |> Repo.all() |> length()
    assert json_response(conn, 200)["raw"] == instance.raw
  end

  test "error not found for user from another organisation", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:membership, organisation: current_user.organisation)
    user = insert(:user)
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, current_user)

    conn = get(conn, Routes.v1_instance_path(conn, :show, instance.uuid))

    assert json_response(conn, 404) == "Not Found"
  end

  test "lock unlock locks if editable true", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:membership, organisation: current_user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, current_user)

    content_type =
      insert(:content_type, creator: current_user, organisation: current_user.organisation)

    instance = insert(:instance, creator: current_user, content_type: content_type)

    conn =
      patch(conn, Routes.v1_instance_path(conn, :lock_unlock, instance.uuid), %{editable: true})

    assert json_response(conn, 200)["content"]["editable"] == true
  end
end
