defmodule WraftDocWeb.Api.V1.InstanceControllerTest do
  @moduledoc """
  Test module for instance controller
  """

  use WraftDocWeb.ConnCase
  @moduletag :controller
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
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    params = Map.merge(@valid_attrs, %{state_id: state.id, vendor_id: vendor.id})

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.id), params)
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
    params = Map.merge(@invalid_attrs, %{state_id: state.id, vendor_id: vendor.id})

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.id), params)
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
      @valid_attrs |> Map.put(:content_type_id, content_type.id) |> Map.put(:state_id, state.id)

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_instance_path(conn, :update, instance.id, params))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 200)["content"]["raw"] == @valid_attrs.raw
    assert count_before == Instance |> Repo.all() |> length()
  end

  test "update instances creates instance version too", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type, editable: true)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    content_type = insert(:content_type)
    state = insert(:state)

    params =
      @valid_attrs |> Map.put(:content_type_id, content_type.id) |> Map.put(:state_id, state.id)

    version_count_before = Version |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_instance_path(conn, :update, instance.id, params))
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
      |> put(Routes.v1_instance_path(conn, :update, instance.id, @invalid_attrs))
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

    conn = get(conn, Routes.v1_instance_path(conn, :index, content_type.id))
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

    conn = get(conn, Routes.v1_instance_path(conn, :show, instance.id))

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
    assert json_response(conn, 400)["errors"] == "The Instance id does not exist..!"
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

    conn = delete(conn, Routes.v1_instance_path(conn, :delete, instance.id))
    assert count_before - 1 == Instance |> Repo.all() |> length()
    assert json_response(conn, 200)["raw"] == instance.raw
  end

  test "error invalid id for user from another organisation", %{conn: conn} do
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

    conn = get(conn, Routes.v1_instance_path(conn, :show, instance.id))

    assert json_response(conn, 400)["errors"] == "The Instance id does not exist..!"
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
      patch(conn, Routes.v1_instance_path(conn, :lock_unlock, instance.id), %{editable: true})

    assert json_response(conn, 200)["content"]["editable"] == true
  end

  test "can't update if the instance is editable false", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:membership, organisation: current_user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, current_user)

    content_type =
      insert(:content_type, creator: current_user, organisation: current_user.organisation)

    instance =
      insert(:instance, creator: current_user, content_type: content_type, editable: false)

    conn = patch(conn, Routes.v1_instance_path(conn, :update, instance.id), @valid_attrs)

    assert json_response(conn, 422)["errors"] ==
             "The instance is not avaliable to edit..!!"
  end

  test "search instances searches instances by title on serialized", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:membership, organisation: current_user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, current_user)

    content_type =
      insert(:content_type, creator: current_user, organisation: current_user.organisation)

    i1 =
      insert(:instance,
        creator: current_user,
        content_type: content_type,
        serialized: %{title: "Offer letter", body: "Offer letter body"}
      )

    i2 =
      insert(:instance,
        creator: current_user,
        content_type: content_type,
        serialized: %{title: "Releival letter", body: "Releival letter body"}
      )

    conn = get(conn, Routes.v1_instance_path(conn, :search), key: "offer")

    contents = json_response(conn, 200)["contents"]

    assert contents
           |> Enum.map(fn x -> x["content"]["instance_id"] end)
           |> List.to_string() =~ i1.instance_id
  end

  test "change/2 lists changes in a version with its previous version", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:membership, organisation: current_user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, current_user)

    content_type =
      insert(:content_type, creator: current_user, organisation: current_user.organisation)

    instance =
      insert(:instance, creator: current_user, content_type: content_type, editable: false)

    insert(:instance_version,
      content: instance,
      version_number: 1,
      raw: "Offer letter to mohammed sadique"
    )

    iv2 =
      insert(:instance_version,
        content: instance,
        version_number: 2,
        raw: "Offer letter to ibrahim sadique to the position"
      )

    conn = get(conn, Routes.v1_instance_path(conn, :change, instance.id, iv2.id))

    assert length(json_response(conn, 200)["del"]) > 0
    assert length(json_response(conn, 200)["ins"]) > 0
  end
end
