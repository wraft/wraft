defmodule WraftDoc.EnterpriseTest do
  import Ecto.Query
  import Ecto
  import WraftDoc.Factory
  use WraftDoc.ModelCase
  use ExUnit.Case
  use Bamboo.Test

  alias WraftDoc.{
    Repo,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Enterprise.Organisation,
    Enterprise.ApprovalSystem,
    Enterprise
  }

  test "get flow returns flow data by uuid" do
    flow = insert(:flow)
    r_flow = Enterprise.get_flow(flow.uuid)
    assert flow.name == r_flow.name
  end

  test "get state returns states data " do
    state = insert(:state)
    r_state = Enterprise.get_state(state.uuid)
    assert state.state == r_state.state
  end

  test "create flow creates a flow in database" do
    %{name: name, creator: user} = insert(:flow)
    count_before = Flow |> Repo.all() |> length()
    flow = Enterprise.create_flow(user, %{"name" => name})
    count_after = Flow |> Repo.all() |> length()
    assert flow.name == name
    assert count_before + 1 == count_after
  end

  test "flow index returns the list of flows" do
    user = insert(:user)
    f1 = insert(:flow, creator: user, organisation: user.organisation)
    f2 = insert(:flow, creator: user, organisation: user.organisation)

    flow_index = Enterprise.flow_index(user, %{page_number: 1})

    assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f1.name
    assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f2.name
  end

  test "show flow preloads flow with creator and states" do
    flow = insert(:flow)
    state = insert(:state, creator: flow.creator, flow: flow)
    flow = Enterprise.show_flow(flow.uuid)

    assert Enum.map(flow.states, fn x -> x.state end) == [state.state]
  end

  test "update flow updates a flow data" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()
    %Flow{name: name} = Enterprise.update_flow(flow, flow.creator, %{name: "flow 2"})
    count_after = Flow |> Repo.all() |> length()
    assert name == "flow 2"
    assert count_before == count_after
  end

  test "delete flow deletes a flow" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()
    Enterprise.delete_flow(flow, flow.creator)
    count_after = Flow |> Repo.all() |> length()
    assert count_before - 1 == count_after
  end

  test "create default states creates two states per flow" do
    flow = insert(:flow)
    state_count_before = State |> Repo.all() |> length()

    states = Enterprise.create_default_states(flow.creator, flow)
    state_count_after = State |> Repo.all() |> length()
    assert state_count_before + 2 == state_count_after

    assert Enum.map(states, fn x -> x.state end) |> List.to_string() =~ "Draft"
    assert Enum.map(states, fn x -> x.state end) |> List.to_string() =~ "Publish"
  end

  test "create state creates a state " do
    flow = insert(:flow)
    count_before = State |> Repo.all() |> length()
    state = Enterprise.create_state(flow.creator, flow, %{"state" => "Review", "order" => 2})
    assert count_before + 1 == State |> Repo.all() |> length()
    assert state.state == "Review"
    assert state.order == 2
  end

  test "state index lists all states under a flow" do
    flow = insert(:flow)
    s1 = insert(:state, flow: flow, creator: flow.creator)
    s2 = insert(:state, flow: flow, creator: flow.creator)

    states = Enterprise.state_index(flow.uuid, %{page_number: 1})

    assert Enum.map(states.entries, fn x -> x.state end) |> List.to_string() =~ s1.state
    assert Enum.map(states.entries, fn x -> x.state end) |> List.to_string() =~ s2.state
  end

  test "shuffle order updates the order of state" do
    flow = insert(:flow)
    state = insert(:state, flow: flow)
    order = state.order
    states = Enterprise.shuffle_order(state, 1)
  end

  test "delete states deletes and returns a state " do
    user = insert(:user)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    state = insert(:state, creator: user, organisation: user.organisation, flow: flow)
    count_before = State |> Repo.all() |> length()
    {:ok, d_state} = Enterprise.delete_state(state, user)
    count_after = State |> Repo.all() |> length()

    assert count_before - 1 == count_after
    assert state.state == d_state.state
  end

  test "get organisation returns the organisation by id" do
    organisation = insert(:organisation)
    g_organisation = Enterprise.get_organisation(organisation.uuid)
    assert organisation.name == g_organisation.name
  end

  test "create organisation creates a organisation " do
    user = insert(:user)

    params = %{
      "name" => "ACC Sru",
      "legal_name" => "Acc sru pvt ltd",
      "address" => "Kodappalaya dikku estate",
      "gstin" => "32SDFASDF65SD6F"
    }

    count_before = Organisation |> Repo.all() |> length()

    {:ok, organisation} = Enterprise.create_organisation(user, params)

    count_ater = Organisation |> Repo.all() |> length()

    assert count_before + 1 == count_ater
    assert organisation.name == params["name"]
    assert organisation.legal_name == params["legal_name"]
  end

  test "update organisation updates an organisation" do
    organisation = insert(:organisation)
    count_before = Organisation |> Repo.all() |> length()

    {:ok, organisation} =
      Enterprise.update_organisation(organisation, %{
        "name" => "Abc enterprices",
        "legal_name" => "Abc pvt ltd"
      })

    count_after = Organisation |> Repo.all() |> length()
    assert count_before == count_after
    assert organisation.name == "Abc enterprices"
  end

  test "delete organisation deletes a row and returns organisation data" do
    organisation = insert(:organisation)
    count_before = Organisation |> Repo.all() |> length()
    {:ok, d_organisation} = Enterprise.delete_organisation(organisation)
    count_after = Organisation |> Repo.all() |> length()

    assert count_before - 1 == count_after
    assert organisation.name == d_organisation.name
  end

  test "create aprroval system create a solution to creat a system" do
    user = insert(:user)
    instance = insert(:instance, creator: user)
    pre_state = insert(:state, creator: user)
    post_state = insert(:state, creator: user)
    approver = insert(:user)
    count_before = ApprovalSystem |> Repo.all() |> length()

    approval_system =
      Enterprise.create_approval_system(user, %{
        "instance_id" => instance.uuid,
        "pre_state_id" => pre_state.uuid,
        "post_state_id" => post_state.uuid,
        "approver_id" => approver.uuid
      })
      |> Repo.preload([:instance])

    count_after = ApprovalSystem |> Repo.all() |> length()
    assert count_before + 1 == count_after
    assert approval_system.instance.uuid == instance.uuid
  end

  test "get approval system returns apprval system data" do
    %{uuid: uuid, instance: instance, pre_state: _pre_state} = insert(:approval_system)
    approval_system = Enterprise.get_approval_system(uuid)
    assert approval_system.instance.uuid == instance.uuid
  end

  test "update approval system updates a system" do
    user = insert(:user)
    approval_system = insert(:approval_system, user: user)
    instance = insert(:instance, creator: user)
    count_before = ApprovalSystem |> Repo.all() |> length()

    updated_approval_system =
      Enterprise.update_approval_system(approval_system, %{
        "instance_id" => instance.uuid,
        "pre_state_id" => approval_system.pre_state.uuid,
        "post_state_id" => approval_system.post_state.uuid,
        "approver_id" => approval_system.approver.uuid
      })

    count_after = ApprovalSystem |> Repo.all() |> length()
    assert count_before == count_after
    assert updated_approval_system.instance.uuid == approval_system.instance.uuid
  end

  test "delete approval system deletes and returns the data" do
    user = insert(:user)
    approval_system = insert(:approval_system, user: user)
    count_before = ApprovalSystem |> Repo.all() |> length()
    {:ok, d_approval_system} = Enterprise.delete_approval_system(approval_system)
    count_after = ApprovalSystem |> Repo.all() |> length()
    assert count_before - 1 == count_after
    assert approval_system.instance.uuid == d_approval_system.instance.uuid
  end

  test "approve content changes the state of instace from pre state to post state" do
    user = insert(:user)
    content_type = insert(:content_type, creator: user)
    state = insert(:state, creator: user, flow: content_type.flow)
    instance = insert(:instance, content_type: content_type, creator: user, state: state)
    post_state = insert(:state, flow: content_type.flow, creator: user)

    approval_system =
      insert(:approval_system,
        user: user,
        instance: instance,
        pre_state: state,
        post_state: post_state
      )

    approved = Enterprise.approve_content(user, approval_system)

    assert approval_system.post_state.id == approved.instance.state_id
  end

  test "check permission grand a permission for admin user to enter any organisation" do
    role = insert(:role, name: "admin")
    organisation = insert(:organisation)
    user = insert(:user, role: role)
    assert Enterprise.check_permission(user, organisation.uuid) == organisation
  end

  test "check permission grand permission for user within organisation" do
    role = insert(:role, name: "user")
    organisation = insert(:organisation)
    user = insert(:user, role: role, organisation: organisation)
    assert Enterprise.check_permission(user, organisation.uuid) == organisation
  end

  test "check permission reject permmision to enter another organisation" do
    role = insert(:role, name: "user")
    organisation = insert(:organisation)
    user = insert(:user, role: role)
    assert Enterprise.check_permission(user, organisation.uuid) == {:error, :no_permission}
  end

  test "already a member return error for existing email" do
    user = insert(:user)
    assert Enterprise.already_member?(user.email) == {:error, :already_member}
  end

  test "already a member return ok for email does not exist" do
    assert Enterprise.already_member?("kdgasd@gami.com") == :ok
  end

  test "invite member send a E-mail to invite a member and returns an oban job" do
    user = insert(:user)
    to_email = "myemail@app.com"
    {:ok, oban_job} = Enterprise.invite_team_member(user, user.organisation, to_email)
    assert oban_job.args.email == to_email
  end
end
