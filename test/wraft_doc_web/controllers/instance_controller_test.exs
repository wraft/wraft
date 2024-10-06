defmodule WraftDocWeb.Api.V1.InstanceControllerTest do
  @moduledoc """
  Test module for instance controller
  """
  use WraftDocWeb.ConnCase

  @moduletag :controller

  import ExUnit.CaptureLog
  import Mox

  alias WraftDoc.Document.Instance
  alias WraftDoc.Document.InstanceApprovalSystem
  alias WraftDoc.Repo

  @valid_attrs %{
    instance_id: "OFFL01",
    raw: "Content",
    serialized: %{title: "updated Title of the content", body: "updated Body of the content"}
  }
  @invalid_attrs %{raw: ""}

  setup :verify_on_exit!

  test "create instances by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)
    [organisation] = user.owned_organisations
    flow = insert(:flow, organisation: organisation)
    insert(:state, organisation: organisation, flow: flow, order: 1)
    content_type = insert(:content_type, organisation: organisation, flow: flow)

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.id), @valid_attrs)
      |> doc(operation_id: "create_instance")

    assert json_response(conn, 200)["content"]["raw"] == @valid_attrs.raw
    assert count_before + 1 == Instance |> Repo.all() |> length()
  end

  test "adds log on succesfully creating an instance", %{conn: conn} do
    Logger.configure(level: :info)
    user = conn.assigns.current_user
    insert(:profile, user: user)
    [organisation] = user.owned_organisations
    flow = insert(:flow, organisation: organisation)
    insert(:state, organisation: organisation, flow: flow, order: 1)
    content_type = insert(:content_type, organisation: organisation, flow: flow)

    assert capture_log([level: :info], fn ->
             post(conn, Routes.v1_instance_path(conn, :create, content_type.id), @valid_attrs)
           end) =~ "Create content success"

    Logger.configure(level: :warn)
  end

  test "does not create instances by invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    [organisation] = user.owned_organisations
    flow = insert(:flow, organisation: organisation)
    insert(:state, organisation: organisation, flow: flow, order: 1)
    content_type = insert(:content_type, organisation: organisation, flow: flow)

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.id), @invalid_attrs)
      |> doc(operation_id: "create_instance")

    assert json_response(conn, 422)["errors"]["raw"] == ["can't be blank"]
    assert count_before == Instance |> Repo.all() |> length()
  end

  test "adds error log when create instance fails", %{conn: conn} do
    user = conn.assigns.current_user
    [organisation] = user.owned_organisations
    flow = insert(:flow, organisation: organisation)
    insert(:state, organisation: organisation, flow: flow, order: 1)
    content_type = insert(:content_type, organisation: organisation, flow: flow)

    assert capture_log([level: :info], fn ->
             post(conn, Routes.v1_instance_path(conn, :create, content_type.id), @invalid_attrs)
           end) =~ "Create content failed"
  end

  test "create instance from content type with approval system also create instance approval systems",
       %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)
    [organisation] = user.owned_organisations
    u2 = insert(:user)
    insert(:user_organisation, user: u2, organisation: organisation)
    flow = insert(:flow, organisation: organisation)
    insert(:state, organisation: organisation, flow: flow, order: 1)
    insert(:approval_system, flow: flow, approver: u2)
    content_type = insert(:content_type, organisation: organisation, flow: flow)

    ias_count_before = InstanceApprovalSystem |> Repo.all() |> length()

    count_before = Instance |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_instance_path(conn, :create, content_type.id), @valid_attrs)
      |> doc(operation_id: "create_instance")

    ias_count_after = InstanceApprovalSystem |> Repo.all() |> length()

    assert json_response(conn, 200)["content"]["raw"] == @valid_attrs.raw

    assert List.first(json_response(conn, 200)["instance_approval_systems"])["approver"]["name"] ==
             u2.name

    assert ias_count_before + 1 == ias_count_after
    assert count_before + 1 == Instance |> Repo.all() |> length()
  end

  test "update instances on valid attributes", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)

    content_type =
      insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

    instance = insert(:instance, creator: user, content_type: content_type)

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

  test "does't update instances for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    content_type =
      insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

    instance = insert(:instance, creator: user, content_type: content_type)

    conn =
      conn
      |> put(Routes.v1_instance_path(conn, :update, instance.id, @invalid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 422)["errors"]["raw"] == ["can't be blank"]
  end

  test "index lists all instances under a content type", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)
    content_type = insert(:content_type)

    dt1 = insert(:instance, creator: user, content_type: content_type)
    dt2 = insert(:instance, creator: user, content_type: insert(:content_type))

    conn = get(conn, Routes.v1_instance_path(conn, :index, content_type.id))
    dt_index = json_response(conn, 200)["contents"]
    instances = Enum.map(dt_index, fn %{"content" => %{"raw" => raw}} -> raw end)
    assert List.to_string(instances) =~ dt1.raw
    assert List.to_string(instances) =~ dt2.raw
  end

  # FIXME need to fix this
  test "all templates lists all instances under an organisation", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)
    [organisation] = user.owned_organisations
    ct1 = insert(:content_type, organisation: organisation)
    ct2 = insert(:content_type, organisation: organisation)

    dt1 = insert(:instance, content_type: ct1, creator: user)
    dt2 = insert(:instance, content_type: ct2, creator: user)

    conn = get(conn, Routes.v1_instance_path(conn, :all_contents))

    dt_index = json_response(conn, 200)["contents"]

    instances =
      dt_index |> Enum.map(fn %{"content" => %{"raw" => raw}} -> raw end) |> List.to_string()

    assert instances =~ dt1.raw
    assert instances =~ dt2.raw
  end

  test "show renders instance details by id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)
    [organisation] = user.owned_organisations
    u2 = insert(:user)
    insert(:user_organisation, user: u2, organisation: organisation)
    flow = insert(:flow, organisation: organisation)
    s = insert(:state, organisation: organisation, flow: flow, order: 1)
    as = insert(:approval_system, flow: flow, approver: u2, pre_state: s)
    content_type = insert(:content_type, organisation: organisation, flow: flow)
    instance = insert(:instance, creator: user, content_type: content_type, state: s)

    conn = get(conn, Routes.v1_instance_path(conn, :show, instance.id))

    assert json_response(conn, 200)["content"]["raw"] == instance.raw

    assert json_response(conn, 200)["state"]["approval_system"]["approval_system"]["id"] == as.id
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn = get(conn, Routes.v1_instance_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The Instance id does not exist..!"
  end

  describe "DELETE /contents/:id" do
    # FIXME need to fix this
    test "delete instance by given id", %{conn: conn} do
      user = conn.assigns.current_user

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      instance = insert(:instance, creator: user, content_type: content_type)

      ExAwsMock
      |> expect(
        :stream!,
        fn %ExAws.Operation.S3{} = operation ->
          assert operation.http_method == :get
          assert operation.params == %{"prefix" => "uploads/contents/#{instance.instance_id}"}

          {
            :ok,
            %{
              body: %{
                contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
              }
            }
          }
        end
      )
      |> expect(:request, fn %ExAws.Operation.S3DeleteAllObjects{} ->
        {:ok, [%{body: "Some XML response"}]}
      end)

      conn = delete(conn, Routes.v1_instance_path(conn, :delete, instance.id))
      assert json_response(conn, 200)["raw"] == instance.raw
      refute Repo.get(Instance, instance.id)
    end
  end

  test "error invalid id for user from another organisation", %{conn: conn} do
    instance = insert(:instance)

    conn = get(conn, Routes.v1_instance_path(conn, :show, instance.id))

    assert json_response(conn, 400)["errors"] == "The Instance id does not exist..!"
  end

  describe "state_update" do
    test "returns success response on updating instance state successfully", %{conn: conn} do
      current_user = conn.assigns[:current_user]
      insert(:profile, user: current_user)
      [organisation] = current_user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, flow: content_type.flow, organisation: organisation)
      instance = insert(:instance, content_type: content_type, creator: current_user)

      conn =
        patch(conn, Routes.v1_instance_path(conn, :state_update, instance.id), %{
          state_id: state.id
        })

      assert response = json_response(conn, 200)
      assert response["state"]["id"] == state.id
    end

    test "returns 400 when update fails", %{conn: conn} do
      current_user = conn.assigns[:current_user]
      [organisation] = current_user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)
      instance = insert(:instance, content_type: content_type)

      conn =
        patch(conn, Routes.v1_instance_path(conn, :state_update, instance.id), %{
          state_id: state.id
        })

      assert response = json_response(conn, 400)
      assert %{"errors" => "Something went wrong.!"} == response
    end

    test "returns 400 when instance is not found", %{conn: conn} do
      current_user = conn.assigns[:current_user]
      content_type = insert(:content_type)

      state =
        insert(:state,
          flow: content_type.flow,
          organisation: List.first(current_user.owned_organisations)
        )

      instance = insert(:instance, content_type: content_type)

      conn =
        patch(conn, Routes.v1_instance_path(conn, :state_update, instance.id), %{
          state_id: state.id
        })

      assert response = json_response(conn, 400)
      assert %{"errors" => "The Instance id does not exist..!"} == response
    end

    test "returns 400 when state is not found", %{conn: conn} do
      current_user = conn.assigns[:current_user]

      content_type =
        insert(:content_type, organisation: List.first(current_user.owned_organisations))

      state = insert(:state, flow: content_type.flow)
      instance = insert(:instance, content_type: content_type)

      conn =
        patch(conn, Routes.v1_instance_path(conn, :state_update, instance.id), %{
          state_id: state.id
        })

      assert response = json_response(conn, 400)
      assert %{"errors" => "The id does not exist..!"} == response
    end
  end

  test "lock unlock locks if editable true", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:profile, user: current_user)

    content_type =
      insert(:content_type,
        creator: current_user,
        organisation: List.first(current_user.owned_organisations)
      )

    instance = insert(:instance, creator: current_user, content_type: content_type)

    conn =
      patch(conn, Routes.v1_instance_path(conn, :lock_unlock, instance.id), %{editable: true})

    assert json_response(conn, 200)["content"]["editable"] == true
  end

  test "can't update if the instance is editable false", %{conn: conn} do
    current_user = conn.assigns[:current_user]

    content_type =
      insert(:content_type,
        creator: current_user,
        organisation: List.first(current_user.owned_organisations)
      )

    instance =
      insert(:instance, creator: current_user, content_type: content_type, editable: false)

    conn = patch(conn, Routes.v1_instance_path(conn, :update, instance.id), @valid_attrs)

    assert json_response(conn, 422)["errors"] ==
             "The instance is not avaliable to edit..!!"
  end

  test "search instances searches instances by title on serialized", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    insert(:profile, user: current_user)

    content_type =
      insert(:content_type,
        creator: current_user,
        organisation: List.first(current_user.owned_organisations)
      )

    i1 =
      insert(:instance,
        creator: current_user,
        content_type: content_type,
        serialized: %{title: "Offer letter", body: "Offer letter body"}
      )

    conn = get(conn, Routes.v1_instance_path(conn, :search), key: "offer")

    contents = json_response(conn, 200)["contents"]

    assert contents
           |> Enum.map(fn x -> x["content"]["instance_id"] end)
           |> List.to_string() =~ i1.instance_id
  end

  test "change/2 lists changes in a version with its previous version", %{conn: conn} do
    current_user = conn.assigns[:current_user]

    content_type =
      insert(:content_type,
        creator: current_user,
        organisation: List.first(current_user.owned_organisations)
      )

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

  describe "approve/2" do
    # FIXME need to fix this
    test "approve instance changes the state of instance to post state of approval system", %{
      conn: conn
    } do
      user = conn.assigns.current_user
      insert(:profile, user: user)
      [organisation] = user.owned_organisations
      flow = insert(:flow, organisation: organisation)
      s1 = insert(:state, organisation: organisation, flow: flow, order: 1)
      s2 = insert(:state, organisation: organisation, flow: flow, order: 2)
      as = insert(:approval_system, flow: flow, approver: user, pre_state: s1, post_state: s2)
      content_type = insert(:content_type, organisation: organisation, flow: flow)
      instance = insert(:instance, creator: user, content_type: content_type, state: s1)
      insert(:instance_approval_system, instance: instance, approval_system: as)

      conn = put(conn, Routes.v1_instance_path(conn, :approve, instance.id))

      assert json_response(conn, 200)["state"]["state"] == s2.state
    end

    # FIXME need to fix this
    test "return error no permission for a wrong approver", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      u2 = insert(:user)
      insert(:user_organisation, user: u2, organisation: organisation)
      flow = insert(:flow, organisation: organisation)
      s1 = insert(:state, organisation: organisation, flow: flow, order: 1)
      s2 = insert(:state, organisation: organisation, flow: flow, order: 2)
      _as = insert(:approval_system, flow: flow, approver: u2, pre_state: s1, post_state: s2)
      content_type = insert(:content_type, organisation: organisation, flow: flow)
      instance = insert(:instance, creator: user, content_type: content_type, state: s1)

      conn = put(conn, Routes.v1_instance_path(conn, :approve, instance.id))

      assert json_response(conn, 401)["errors"] == "You are not authorized for this action.!"
    end
  end

  describe "reject/2" do
    # FIXME need to fix this
    test "reject instance changes the state of instance to pre state of rejection system", %{
      conn: conn
    } do
      user = conn.assigns.current_user
      insert(:profile, user: user)
      [organisation] = user.owned_organisations
      flow = insert(:flow, organisation: organisation)
      s1 = insert(:state, organisation: organisation, flow: flow, order: 1)
      s2 = insert(:state, organisation: organisation, flow: flow, order: 2)
      s3 = insert(:state, organisation: organisation, flow: flow, order: 3)
      as = insert(:approval_system, flow: flow, approver: user, pre_state: s1, post_state: s2)
      insert(:approval_system, flow: flow, approver: user, pre_state: s2, post_state: s3)
      content_type = insert(:content_type, organisation: organisation, flow: flow)
      instance = insert(:instance, creator: user, content_type: content_type, state: s2)
      insert(:instance_approval_system, instance: instance, approval_system: as)

      conn = put(conn, Routes.v1_instance_path(conn, :reject, instance.id))

      assert json_response(conn, 200)["state"]["state"] == s1.state
    end
  end
end
