defmodule WraftDoc.EnterpriseTest do
  import Ecto.Query
  import Ecto
  import WraftDoc.Factory
  use WraftDoc.ModelCase

  alias WraftDoc.{
    Repo,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Enterprise.Organisation,
    Account,
    Account.User,
    Enterprise.ApprovalSystem,
    Document.Instance,
    Document,
    Enterprise
  }

  test "get flow retrives flow data by uuid" do
    flow = insert(:flow)
    r_flow = Enterprise.get_flow(flow.uuid)
    assert flow.name == r_flow.name
  end

  test "get state retrives states data " do
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
    assert count_before + 1 = count_after
  end

  test "flow index retrives the list of flows" do
    user = insert(:user)
    f1 = insert(:flow, creator: user)
    f2 = insert(:flow, creator: user)

    flow_index = Enterprise.flow_index(user, %{page: 1})
    assert flow_index =~ f1.name
    assert flow_index =~ f1.name
  end

  test "show flow preloads flow with creator and states" do
    flow = insert(:flow)
    state = insert(:state, creator: flow.creator, flow: flow)
    flow = Enterprise.show_flow(flow.uuid)
    assert flow.state == state
  end

  test "update flow updates a flow data" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()
    %Flow{name: name} = Enterprise.update_flow(flow, flow.user, %{name: "flow 2"})
    count_after = Flow |> Repo.all() |> length()
    assert name == "flow 2"
    assert count_before == count_after
  end

  test "delete flow deletes a flow" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()
    Enterprise.delete_flow(flow, flow.user)
    count_after = Flow |> Repo.all() |> length()
    assert count_before - 1 = count_before
  end

  test "create default states creates two states per flow" do
    flow = insert(:flow)
    state_count_before = State |> Repo.all() |> length()

    states = Enterprise.create_default_states(flow.user, flow)
    state_count_after = State |> Repo.all() |> length()
    assert state_count_before + 2 == state_count_after
    assert states =~ "Draft"
    assert state =~ "Publish"
  end
end
