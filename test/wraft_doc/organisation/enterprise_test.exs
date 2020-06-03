defmodule WraftDoc.EnterpriseTest do
  import Ecto.Query
  import Ecto
  import WraftDoc.Factory
  use WraftDoc.DataCase
  use ExUnit.Case
  use Bamboo.Test

  alias WraftDoc.{
    Repo,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Enterprise.Organisation,
    Enterprise.ApprovalSystem,
    Enterprise.Plan,
    Enterprise.Membership.Payment,
    Enterprise
  }

  @valid_razorpay_id "pay_EvM3nS0jjqQMyK"
  @failed_razorpay_id "pay_EvMEpdcZ5HafEl"
  test "get flow returns flow data by uuid" do
    user = insert(:user)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    r_flow = Enterprise.get_flow(flow.uuid, user)
    assert flow.name == r_flow.name
  end

  test "get state returns states data " do
    user = insert(:user)
    state = insert(:state, organisation: user.organisation)
    r_state = Enterprise.get_state(user, state.uuid)
    assert state.state == r_state.state
  end

  test "create a controlled flow by adding conttrolled true and adding three default states" do
    user = insert(:user)

    params = %{
      "name" => "flow 1",
      "controlled" => true,
      "control_data" => %{"pre_state" => "review", "post_state" => "publish", "approver" => user}
    }

    count_before = Flow |> Repo.all() |> length()
    state_count_before = State |> Repo.all() |> length()
    flow = Enterprise.create_flow(user, params)
    count_after = Flow |> Repo.all() |> length()
    state_count_after = State |> Repo.all() |> length()
    assert flow.name == params["name"]
    assert count_before + 1 == count_after
    refute state_count_before == state_count_after
  end

  test "create an uncontrolled flow by adding conttrolled false and adding two default states" do
    user = insert(:user)

    params = %{
      "name" => "flow 1",
      "controlled" => false
    }

    count_before = Flow |> Repo.all() |> length()
    state_count_before = State |> Repo.all() |> length()
    flow = Enterprise.create_flow(user, params)
    count_after = Flow |> Repo.all() |> length()
    state_count_after = State |> Repo.all() |> length()
    assert flow.name == params["name"]
    assert count_before + 1 == count_after
    refute state_count_before == state_count_after
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
    user = insert(:user)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    state = insert(:state, creator: user, flow: flow)
    flow = Enterprise.show_flow(flow.uuid, user)

    assert Enum.map(flow.states, fn x -> x.state end) == [state.state]
  end

  test "update flow updates a flow data" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()

    %Flow{name: name} =
      Enterprise.update_flow(flow, flow.creator, %{"name" => "flow 2", "controlled" => false})

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

  # test "create default states creates two states per flow" do
  #   flow = insert(:flow)
  #   state_count_before = State |> Repo.all() |> length()

  #   states = Enterprise.create_default_states(flow.creator, flow)
  #   state_count_after = State |> Repo.all() |> length()
  #   assert state_count_before + 2 == state_count_after

  #   assert Enum.map(states, fn x -> x.state end) |> List.to_string() =~ "Draft"
  #   assert Enum.map(states, fn x -> x.state end) |> List.to_string() =~ "Publish"
  # end

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
    c_type = insert(:content_type, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: c_type)
    pre_state = insert(:state, organisation: user.organisation)
    post_state = insert(:state, organisation: user.organisation)
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
    user = insert(:user)
    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)

    %{uuid: uuid, instance: instance, pre_state: _pre_state} =
      insert(:approval_system, user: user, organisation: user.organisation, instance: instance)

    approval_system = Enterprise.get_approval_system(uuid, user)
    assert approval_system.instance.uuid == instance.uuid
  end

  test "update approval system updates a system" do
    user = insert(:user)

    content_type = insert(:content_type, creator: user, organisation: user.organisation)
    instance = insert(:instance, creator: user, content_type: content_type)
    pre_state = insert(:state, creator: user, organisation: user.organisation)
    post_state = insert(:state, creator: user, organisation: user.organisation)

    approval_system =
      insert(:approval_system, user: user, organisation: user.organisation, instance: instance)

    count_before = ApprovalSystem |> Repo.all() |> length()

    updated_approval_system =
      Enterprise.update_approval_system(user, approval_system, %{
        "instance_id" => instance.uuid,
        "pre_state_id" => pre_state.uuid,
        "post_state_id" => post_state.uuid,
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

  describe "create_plan/1" do
    test "creates a plan with valid attrs" do
      attrs = %{name: "Basic", description: "A free plan", yearly_amount: 0, monthly_amount: 0}
      count_before = Plan |> Repo.all() |> length()
      {:ok, plan} = Enterprise.create_plan(attrs)

      assert count_before + 1 == Plan |> Repo.all() |> length()
      assert plan.name == attrs.name
      assert plan.description == attrs.description
      assert plan.yearly_amount == attrs.yearly_amount
      assert plan.monthly_amount == attrs.monthly_amount
    end

    test "does not create plan with invalid attrs" do
      count_before = Plan |> Repo.all() |> length()
      {:error, changeset} = Enterprise.create_plan(%{})

      assert count_before == Plan |> Repo.all() |> length()
      assert %{name: ["can't be blank"], description: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "get_plan/1" do
    test "fetches a plan with valid uuid" do
      plan = insert(:plan)
      fetched_plan = Enterprise.get_plan(plan.uuid)

      assert fetched_plan.uuid == plan.uuid
      assert fetched_plan.name == plan.name
    end

    test "returns nil with non-existent uuid" do
      fetched_plan = Enterprise.get_plan(Ecto.UUID.generate())

      assert fetched_plan == nil
    end

    test "returns nil with invalid uuid" do
      fetched_plan = Enterprise.get_plan(1)

      assert fetched_plan == nil
    end
  end

  describe "plan_index/0" do
    test "returns the list of all plans" do
      p1 = insert(:plan)
      p2 = insert(:plan)

      plans = Enterprise.plan_index()
      plan_names = plans |> Enum.map(fn x -> x.name end) |> List.to_string()
      assert plans |> length() == 2
      assert plan_names =~ p1.name
      assert plan_names =~ p2.name
    end

    test "returns empty list when there are no plans" do
      plans = Enterprise.plan_index()
      assert plans == []
    end
  end

  describe "update_plan/2" do
    test "updates a plan with valid attrs" do
      plan = insert(:plan)
      attrs = %{name: "Basic", description: "Basic plan", yearly_amount: 200, monthly_amount: 105}
      {:ok, updated_plan} = Enterprise.update_plan(plan, attrs)

      assert updated_plan.uuid == plan.uuid
      assert updated_plan.name == attrs.name
      assert updated_plan.description == attrs.description
      assert updated_plan.yearly_amount == attrs.yearly_amount
      assert updated_plan.monthly_amount == attrs.monthly_amount
    end

    test "does not update plan with invalid attrs" do
      plan = insert(:plan)
      attrs = %{name: ""}
      {:error, changeset} = Enterprise.update_plan(plan, attrs)

      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end

    test "returns nil with wrong input" do
      attrs = %{name: ""}
      response = Enterprise.update_plan(nil, attrs)

      assert response == nil
    end
  end

  describe "delete_plan/2" do
    test "deletes a plan when valid plan struct is given" do
      plan = insert(:plan)

      before_count = Plan |> Repo.all() |> length()
      {:ok, deleted_plan} = Enterprise.delete_plan(plan)

      assert before_count - 1 == Plan |> Repo.all() |> length()
      assert deleted_plan.uuid == plan.uuid
    end

    test "returns nil when given input is not a plan struct" do
      response = Enterprise.delete_plan(nil)
      assert response == nil
    end
  end

  describe "get_membership/1" do
    test "fetches a membership with valid uuid" do
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership.uuid)

      assert fetched_membership.uuid == membership.uuid
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.organisation_id == membership.organisation_id
      assert fetched_membership.start_date == membership.start_date
      assert fetched_membership.end_date == membership.end_date
      assert fetched_membership.plan_duration == membership.plan_duration
    end

    test "returns nil with non-existent uuid" do
      fetched_membership = Enterprise.get_membership(Ecto.UUID.generate())

      assert fetched_membership == nil
    end

    test "returns nil with invalid uuid" do
      fetched_membership = Enterprise.get_membership(1)

      assert fetched_membership == nil
    end
  end

  describe "get_membership/2" do
    test "fetches a membership with valid parameters" do
      user = insert(:user)
      membership = insert(:membership, organisation: user.organisation)
      fetched_membership = Enterprise.get_membership(membership.uuid, user)

      assert fetched_membership.uuid == membership.uuid
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.organisation_id == membership.organisation_id
      assert fetched_membership.start_date == membership.start_date
      assert fetched_membership.end_date == membership.end_date
      assert fetched_membership.plan_duration == membership.plan_duration
    end

    test "returns nil with non-existent uuid" do
      user = insert(:user)
      fetched_membership = Enterprise.get_membership(Ecto.UUID.generate(), user)

      assert fetched_membership == nil
    end

    test "returns nil with invalid parameter" do
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership, nil)

      assert fetched_membership == nil
    end

    test "returns nil with invalid uuid" do
      user = insert(:user)
      fetched_membership = Enterprise.get_membership(1, user)

      assert fetched_membership == nil
    end

    test "returns nil when membership does not belongs to user's organisation" do
      user = insert(:user)
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership.uuid, user)
      assert fetched_membership == nil
    end

    test "returns membership irrespective of organisation when user has admin role" do
      role = insert(:role, name: "admin")
      user = insert(:user, role)
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership.uuid, user)
      assert fetched_membership.uuid == membership.uuid
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.organisation_id == membership.organisation_id
      assert fetched_membership.start_date == membership.start_date
      assert fetched_membership.end_date == membership.end_date
      assert fetched_membership.plan_duration == membership.plan_duration
    end
  end

  describe "get_organisation_membership/1" do
    test "fetches a membership with valid parameters" do
      membership = insert(:membership)
      fetched_membership = Enterprise.get_organisation_membership(membership.organisation.uuid)
      assert fetched_membership.uuid == membership.uuid
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.plan.yearly_amount == membership.plan.yearly_amount
    end

    test "returns nil with non-existent uuid" do
      fetched_membership = Enterprise.get_organisation_membership(Ecto.UUID.generate())

      assert fetched_membership == nil
    end

    test "returns nil with invalid uuid" do
      fetched_membership = Enterprise.get_organisation_membership(1)

      assert fetched_membership == nil
    end
  end

  describe "update_membership/4" do
    test "upadtes membership and creates new payment with valid attrs" do
      user = insert(:user)
      membership = insert(:membership)
      plan = insert(:plan, monthly_amount: 100_000)
      payment_count = Payment |> Repo.all() |> length
      {:ok, razorpay} = @valid_razorpay_id |> Razorpay.Payment.get()
      new_membership = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count + 1 == Payment |> Repo.all() |> length
      assert new_membership.organisation_id == membership.organisation_id
      assert new_membership.plan_id == plan.id
    end

    test "does not update membership but creates new payment with failed razorpay id but valid attrs" do
      user = insert(:user)
      membership = insert(:membership, organisation: user.organisation)
      plan = insert(:plan, monthly_amount: 100_000)
      payment_count = Payment |> Repo.all() |> length
      {:ok, razorpay} = @failed_razorpay_id |> Razorpay.Payment.get()
      {:ok, payment} = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count + 1 == Payment |> Repo.all() |> length
      assert payment.organisation_id == membership.organisation_id
      assert payment.membership_id == membership.id
      assert payment.from_plan_id == membership.plan_id
      assert payment.to_plan_id == plan.id
    end

    test "does not update membership and returns nil with invalid razorpay ID" do
      user = insert(:user)
      membership = insert(:membership)
      plan = insert(:plan)
      {:error, razorpay} = "wrong_id" |> Razorpay.Payment.get()
      payment_count = Payment |> Repo.all() |> length
      response = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count == Payment |> Repo.all() |> length
      assert response == nil
    end

    test "does not update membership and returns wrong amount error when razorpay amount does not match any plan amount" do
      user = insert(:user)
      membership = insert(:membership)
      plan = insert(:plan)
      {:ok, razorpay} = @valid_razorpay_id |> Razorpay.Payment.get()
      payment_count = Payment |> Repo.all() |> length
      response = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count == Payment |> Repo.all() |> length
      assert response == {:error, :wrong_amount}
    end

    test "does not update membership with wrong parameters" do
      response = Enterprise.update_membership(nil, nil, nil, nil)
      assert response == nil
    end
  end

  describe "payment_index/2" do
    test "returns the list of all payments in an organisation" do
      organisation = insert(:organisation)
      p1 = insert(:payment, organisation: organisation)
      p2 = insert(:payment, organisation: organisation)

      list = Enterprise.payment_index(organisation.id, %{})

      assert list.entries |> Enum.map(fn x -> x.razorpay_id end) |> List.to_string() =~
               p1.razorpay_id

      assert list.entries |> Enum.map(fn x -> x.razorpay_id end) |> List.to_string() =~
               p2.razorpay_id
    end
  end

  describe "get_payment/2" do
    test "returns the payment in the user's organisation with given id" do
      user = insert(:user)
      payment = insert(:payment, organisation: user.organisation)
      fetched_payement = Enterprise.get_payment(payment.uuid, user)
      assert fetched_payement.razorpay_id == payment.razorpay_id
      assert fetched_payement.uuid == payment.uuid
    end

    test "returns nil when payment does not belong to the user's organisation" do
      user = insert(:user)
      payment = insert(:payment)
      response = Enterprise.get_payment(payment.uuid, user)
      assert response == nil
    end

    test "returns payment irrespective of organisation when user has admin role" do
      role = insert(:role, name: "admin")
      user = insert(:user, role)
      payment = insert(:payment)
      fetched_payement = Enterprise.get_payment(payment.uuid, user)
      assert fetched_payement.razorpay_id == payment.razorpay_id
      assert fetched_payement.uuid == payment.uuid
    end

    test "returns nil for non existent payment" do
      user = insert(:user)
      response = Enterprise.get_payment(Ecto.UUID.generate(), user)
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Enterprise.get_payment(Ecto.UUID.generate(), nil)
      assert response == nil
    end
  end

  describe "show_payment/2" do
    test "returns the payment in the user's organisation with given id" do
      user = insert(:user)
      payment = insert(:payment, organisation: user.organisation)
      fetched_payement = Enterprise.show_payment(payment.uuid, user)
      assert fetched_payement.razorpay_id == payment.razorpay_id
      assert fetched_payement.uuid == payment.uuid
      assert fetched_payement.organisation.uuid == payment.organisation.uuid
      assert fetched_payement.creator.uuid == payment.creator.uuid
      assert fetched_payement.membership.uuid == payment.membership.uuid
      assert fetched_payement.from_plan.uuid == payment.from_plan.uuid
      assert fetched_payement.to_plan.uuid == payment.to_plan.uuid
    end

    test "returns nil when payment does not belong to the user's organisation" do
      user = insert(:user)
      payment = insert(:payment)
      response = Enterprise.show_payment(payment.uuid, user)
      assert response == nil
    end

    test "returns nil for non existent payment" do
      user = insert(:user)
      response = Enterprise.show_payment(Ecto.UUID.generate(), user)
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Enterprise.show_payment(Ecto.UUID.generate(), nil)
      assert response == nil
    end
  end
end
