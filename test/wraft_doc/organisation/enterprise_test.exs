defmodule WraftDoc.EnterpriseTest do
  import Ecto.Query
  import Ecto
  import WraftDoc.Factory
  use WraftDoc.DataCase
  use ExUnit.Case
  @moduletag :enterprise

  alias WraftDoc.Account.AuthToken
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Repo

  @valid_razorpay_id "pay_EvM3nS0jjqQMyK"
  @failed_razorpay_id "pay_EvMEpdcZ5HafEl"
  test "get flow returns flow data by id" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    r_flow = Enterprise.get_flow(flow.id, user)
    assert flow.name == r_flow.name
  end

  test "get state returns states data " do
    user = insert(:user_with_organisation)
    state = insert(:state, organisation: user.organisation)
    r_state = Enterprise.get_state(user, state.id)
    assert state.state == r_state.state
  end

  test "create a controlled flow by adding conttrolled true and adding three default states" do
    user = insert(:user_with_organisation)

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
    user = insert(:user_with_organisation)

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
    user = insert(:user_with_organisation)
    f1 = insert(:flow, creator: user, organisation: user.organisation)
    f2 = insert(:flow, creator: user, organisation: user.organisation)

    flow_index = Enterprise.flow_index(user, %{page_number: 1})

    assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f1.name
    assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f2.name
  end

  test "show flow preloads flow with creator and states" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    state = insert(:state, creator: user, flow: flow)
    flow = Enterprise.show_flow(flow.id, user)

    assert Enum.map(flow.states, fn x -> x.state end) == [state.state]
  end

  test "update flow updates a flow data" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()

    %Flow{name: name} = Enterprise.update_flow(flow, %{"name" => "flow 2", "controlled" => false})

    count_after = Flow |> Repo.all() |> length()
    assert name == "flow 2"
    assert count_before == count_after
  end

  test "delete flow deletes a flow" do
    flow = insert(:flow)
    count_before = Flow |> Repo.all() |> length()
    Enterprise.delete_flow(flow)
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
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user)
    count_before = State |> Repo.all() |> length()
    state = Enterprise.create_state(user, flow, %{"state" => "Review", "order" => 2})
    assert count_before + 1 == State |> Repo.all() |> length()
    assert state.state == "Review"
    assert state.order == 2
  end

  test "state index lists all states under a flow" do
    flow = insert(:flow)
    s1 = insert(:state, flow: flow, creator: flow.creator)
    s2 = insert(:state, flow: flow, creator: flow.creator)

    states = Enterprise.state_index(flow.id, %{page_number: 1})

    assert states.entries |> Enum.map(fn x -> x.state end) |> List.to_string() =~ s1.state
    assert states.entries |> Enum.map(fn x -> x.state end) |> List.to_string() =~ s2.state
  end

  # TODO - No asserts added (M Sadique)
  test "shuffle order updates the order of state" do
    flow = insert(:flow)
    state = insert(:state, flow: flow)
    state.order
    Enterprise.shuffle_order(state, 1)
  end

  test "delete states deletes and returns a state " do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)
    state = insert(:state, creator: user, organisation: user.organisation, flow: flow)
    count_before = State |> Repo.all() |> length()
    {:ok, d_state} = Enterprise.delete_state(state)
    count_after = State |> Repo.all() |> length()

    assert count_before - 1 == count_after
    assert state.state == d_state.state
  end

  test "get organisation returns the organisation by id" do
    organisation = insert(:organisation)
    g_organisation = Enterprise.get_organisation(organisation.id)
    assert organisation.name == g_organisation.name
  end

  test "get personal organisation by email returns personal organisation" do
    organisation = insert(:organisation, name: "Personal")
    personal_org = Enterprise.get_personal_org_by_email(organisation.email)
    assert personal_org.name == "Personal"
    assert personal_org.id == organisation.id
  end

  test "create organisation creates a organisation " do
    user = insert(:user)

    params = %{
      "name" => "ACC Sru",
      "legal_name" => "Acc sru pvt ltd",
      "email" => "dikku@kodappalaya.com",
      "address" => "Kodappalaya dikku estate",
      "gstin" => "32SDFASDF65SD6F"
    }

    count_before = Organisation |> Repo.all() |> length()

    organisation = Enterprise.create_organisation(user, params)

    count_ater = Organisation |> Repo.all() |> length()

    assert count_before + 1 == count_ater
    assert organisation.name == params["name"]
    assert organisation.legal_name == params["legal_name"]
  end

  describe "create_personal_organisation/2" do
    test "creates organisation on valid attributes" do
      user = insert(:user)
      insert(:plan, name: "Free Trial")

      params = %{
        "name" => "Personal",
        "email" => "dikku@kodappalaya.com"
      }

      count_before = Organisation |> Repo.all() |> length()

      {:ok, %{organisation: organisation}} = Enterprise.create_personal_organisation(user, params)

      count_after = Organisation |> Repo.all() |> length()

      assert count_before + 1 == count_after
      assert organisation.name == params["name"]
    end

    test "returns error on invalid attributes" do
      user = insert(:user)
      insert(:plan, name: "Free Trial")

      params = %{
        "name" => "Not Personal",
        "email" => "dikku@kodappalaya.com"
      }

      count_before = Organisation |> Repo.all() |> length()

      {:error, _, changeset, _} = Enterprise.create_personal_organisation(user, params)

      count_after = Organisation |> Repo.all() |> length()

      assert count_before == count_after
      assert %{name: ["has invalid format"]} == errors_on(changeset)
    end
  end

  test "update organisation updates an organisation" do
    organisation = insert(:organisation)
    count_before = Organisation |> Repo.all() |> length()

    organisation =
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

  describe "create_approval_system/2" do
    test "create approval system on valid attributes" do
      user = insert(:user_with_organisation)

      pre_state = insert(:state, organisation: user.organisation)
      post_state = insert(:state, organisation: user.organisation)
      approver = insert(:user, organisation: user.organisation)
      flow = insert(:flow, organisation: user.organisation)

      count_before = ApprovalSystem |> Repo.all() |> length()

      params = %{
        "pre_state_id" => pre_state.id,
        "post_state_id" => post_state.id,
        "approver_id" => approver.id,
        "flow_id" => flow.id
      }

      _approval_system = Enterprise.create_approval_system(user, params)

      count_after = ApprovalSystem |> Repo.all() |> length()

      assert count_before + 1 == count_after
    end

    test "do not create approval system on invalid attributes" do
      user = insert(:user)
      count_before = ApprovalSystem |> Repo.all() |> length()
      params = %{}
      {:error, approval_system} = Enterprise.create_approval_system(user, params)
      count_after = ApprovalSystem |> Repo.all() |> length()

      assert count_before == count_after

      assert %{
               post_state_id: ["can't be blank"],
               pre_state_id: ["can't be blank"],
               approver_id: ["can't be blank"],
               flow_id: ["can't be blank"]
             } == errors_on(approval_system)
    end
  end

  test "show approval system returns apprval system data" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)

    %{id: id, flow: flow, pre_state: _pre_state} =
      insert(:approval_system, creator: user, flow: flow)

    approval_system = Enterprise.show_approval_system(id, user)
    assert approval_system.flow.id == flow.id
  end

  test "update approval system updates a system" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: user.organisation)

    pre_state = insert(:state, creator: user, organisation: user.organisation)
    post_state = insert(:state, creator: user, organisation: user.organisation)

    approval_system = insert(:approval_system, creator: user, flow: flow)

    count_before = ApprovalSystem |> Repo.all() |> length()

    updated_approval_system =
      Enterprise.update_approval_system(user, approval_system, %{
        "flow_id" => flow.id,
        "pre_state_id" => pre_state.id,
        "post_state_id" => post_state.id,
        "approver_id" => approval_system.approver.id
      })

    count_after = ApprovalSystem |> Repo.all() |> length()
    assert count_before == count_after
    assert updated_approval_system.flow.id == approval_system.flow.id
  end

  test "delete approval system deletes and returns the data" do
    user = insert(:user)
    approval_system = insert(:approval_system, creator: user)
    count_before = ApprovalSystem |> Repo.all() |> length()
    d_approval_system = Enterprise.delete_approval_system(approval_system)
    count_after = ApprovalSystem |> Repo.all() |> length()
    assert count_before - 1 == count_after
    assert approval_system.flow.id == d_approval_system.flow.id
  end

  # test "approve content changes the state of instace from pre state to post state" do
  #   user = insert(:user)
  #   content_type = insert(:content_type, creator: user)
  #   state = insert(:state, creator: user, flow: content_type.flow)
  #   flow = insert(:flow, content_type: content_type, creator: user)
  #   post_state = insert(:state, flow: content_type.flow, creator: user)

  #   approval_system =
  #     insert(:approval_system,
  #       user: user,

  #       pre_state: state,
  #       post_state: post_state
  #     )

  #   approved = Enterprise.approve_content(user, approval_system)

  #   assert approval_system.post_state.id == approved.instance.state_id
  # end

  test "already a member return error for existing email" do
    user = insert(:user)
    assert Enterprise.already_member(user.email) == {:error, :already_member}
  end

  test "already a member return ok for email does not exist" do
    assert Enterprise.already_member("kdgasd@gami.com") == :ok
  end

  test "invite member send a E-mail to invite a member and returns an oban job" do
    user = insert(:user_with_organisation)
    role = insert(:role)
    to_email = "myemail@app.com"
    {:ok, oban_job} = Enterprise.invite_team_member(user, user.organisation, to_email, role)
    assert oban_job.args.email == to_email
  end

  test "invite member creates an auth token of type invite" do
    user = insert(:user_with_organisation)
    role = insert(:role)
    to_email = "myemail@app.com"
    auth_token_count = AuthToken |> Repo.all() |> length()
    Enterprise.invite_team_member(user, user.organisation, to_email, role)
    assert AuthToken |> Repo.all() |> length() == auth_token_count + 1
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
    test "fetches a plan with valid id" do
      plan = insert(:plan)
      fetched_plan = Enterprise.get_plan(plan.id)

      assert fetched_plan.id == plan.id
      assert fetched_plan.name == plan.name
    end

    test "returns nil with non-existent id" do
      fetched_plan = Enterprise.get_plan(Ecto.UUID.generate())

      assert fetched_plan == {:error, :invalid_id, "Plan"}
    end

    test "returns nil with invalid id" do
      fetched_plan = Enterprise.get_plan(1)

      assert fetched_plan == {:error, :invalid_id, "Plan"}
    end
  end

  describe "plan_index/0" do
    test "returns the list of all plans" do
      p1 = insert(:plan)
      p2 = insert(:plan)

      plans = Enterprise.plan_index()
      plan_names = plans |> Enum.map(fn x -> x.name end) |> List.to_string()
      assert length(plans) == 2
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

      assert updated_plan.id == plan.id
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
      assert deleted_plan.id == plan.id
    end

    test "returns nil when given input is not a plan struct" do
      response = Enterprise.delete_plan(nil)
      assert response == nil
    end
  end

  describe "get_membership/1" do
    test "fetches a membership with valid id" do
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership.id)

      assert fetched_membership.id == membership.id
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.organisation_id == membership.organisation_id
      assert fetched_membership.start_date == membership.start_date
      assert fetched_membership.end_date == membership.end_date
      assert fetched_membership.plan_duration == membership.plan_duration
    end

    test "returns nil with non-existent id" do
      fetched_membership = Enterprise.get_membership(Ecto.UUID.generate())

      assert fetched_membership == nil
    end

    test "returns nil with invalid id" do
      fetched_membership = Enterprise.get_membership(1)

      assert fetched_membership == nil
    end
  end

  describe "get_membership/2" do
    test "fetches a membership with valid parameters" do
      user = insert(:user_with_organisation)
      user = Repo.preload(user, [:roles])
      role_names = Enum.map(user.roles, fn x -> x.name end)
      user = Map.put(user, :role_names, role_names)
      membership = insert(:membership, organisation: user.organisation)
      fetched_membership = Enterprise.get_membership(membership.id, user)

      assert fetched_membership.id == membership.id
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.organisation_id == membership.organisation_id
      assert fetched_membership.start_date == membership.start_date
      assert fetched_membership.end_date == membership.end_date
      assert fetched_membership.plan_duration == membership.plan_duration
    end

    test "returns nil with non-existent id" do
      user = insert(:user_with_organisation)
      fetched_membership = Enterprise.get_membership(Ecto.UUID.generate(), user)

      assert fetched_membership == nil
    end

    test "returns nil with invalid parameter" do
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership, nil)

      assert fetched_membership == nil
    end

    test "returns nil when membership does not belongs to user's organisation" do
      user = insert(:user_with_organisation)
      membership = insert(:membership)
      fetched_membership = Enterprise.get_membership(membership.id, user)
      assert fetched_membership == nil
    end
  end

  describe "get_organisation_membership/1" do
    test "fetches a membership with valid parameters" do
      membership = insert(:membership)
      fetched_membership = Enterprise.get_organisation_membership(membership.organisation.id)
      assert fetched_membership.id == membership.id
      assert fetched_membership.plan_id == membership.plan_id
      assert fetched_membership.plan.yearly_amount == membership.plan.yearly_amount
    end

    test "returns nil with non-existent id" do
      fetched_membership = Enterprise.get_organisation_membership(Ecto.UUID.generate())

      assert fetched_membership == nil
    end

    test "returns nil with invalid id" do
      fetched_membership = Enterprise.get_organisation_membership(1)

      assert fetched_membership == {:error, :invalid_id, "Organisation"}
    end
  end

  describe "update_membership/4" do
    test "upadtes membership and creates new payment with valid attrs" do
      user = insert(:user_with_organisation)
      membership = insert(:membership)
      plan = insert(:plan, monthly_amount: 100_000)
      payment_count = Payment |> Repo.all() |> length
      {:ok, razorpay} = Razorpay.Payment.get(@valid_razorpay_id)
      new_membership = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count + 1 == Payment |> Repo.all() |> length
      assert new_membership.organisation_id == membership.organisation_id
      assert new_membership.plan_id == plan.id
    end

    test "does not update membership but creates new payment with failed razorpay id but valid attrs" do
      user = insert(:user_with_organisation)
      membership = insert(:membership, organisation: user.organisation)
      plan = insert(:plan, monthly_amount: 100_000)
      payment_count = Payment |> Repo.all() |> length
      {:ok, razorpay} = Razorpay.Payment.get(@failed_razorpay_id)
      {:ok, payment} = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count + 1 == Payment |> Repo.all() |> length
      assert payment.organisation_id == membership.organisation_id
      assert payment.membership_id == membership.id
      assert payment.from_plan_id == membership.plan_id
      assert payment.to_plan_id == plan.id
    end

    test "does not update membership and returns nil with invalid razorpay ID" do
      user = insert(:user_with_organisation)
      membership = insert(:membership)
      plan = insert(:plan)
      {:error, razorpay} = Razorpay.Payment.get("wrong_id")
      payment_count = Payment |> Repo.all() |> length
      response = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count == Payment |> Repo.all() |> length
      assert response == {:error, :invalid_id, "RazorPay"}
    end

    test "does not update membership and returns wrong amount error when razorpay amount does not match any plan amount" do
      user = insert(:user_with_organisation)
      membership = insert(:membership)
      plan = insert(:plan)
      {:ok, razorpay} = Razorpay.Payment.get(@valid_razorpay_id)
      payment_count = Payment |> Repo.all() |> length
      response = Enterprise.update_membership(user, membership, plan, razorpay)

      assert payment_count == Payment |> Repo.all() |> length
      assert response == {:error, :wrong_amount}
    end

    test "does not update membership with wrong parameters" do
      response = Enterprise.update_membership(nil, nil, nil, nil)
      assert response == {:error, :invalid_data}
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
      user = insert(:user_with_organisation)
      insert(:user_role, user: user)
      user = Repo.preload(user, [:roles])
      role_names = Enum.map(user.roles, fn x -> x.name end)
      user = Map.put(user, :role_names, role_names)
      payment = insert(:payment, organisation: user.organisation)
      fetched_payement = Enterprise.get_payment(payment.id, user)
      assert fetched_payement.razorpay_id == payment.razorpay_id
      assert fetched_payement.id == payment.id
    end

    test "returns nil when payment does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      payment = insert(:payment)
      response = Enterprise.get_payment(payment.id, user)
      assert response == nil
    end

    # test "returns payment irrespective of organisation when user has admin role" do
    #   role = insert(:role, name: "super_admin")
    #   user = insert(:user)
    #   insert(:user_role, role: role, user: user)
    #   user = Repo.preload(user, [:roles])
    #   role_names = Enum.map(user.roles, fn x -> x.name end)
    #   user = Map.put(user, :role_names, role_names)
    #   payment = insert(:payment)
    #   fetched_payement = Enterprise.get_payment(payment.id, user)
    #   assert fetched_payement.razorpay_id == payment.razorpay_id
    #   assert fetched_payement.id == payment.id
    # end

    test "returns nil for non existent payment" do
      user = insert(:user_with_organisation)
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
      user = insert(:user_with_organisation)
      user = Repo.preload(user, [:roles])
      role_names = Enum.map(user.roles, fn x -> x.name end)
      user = Map.put(user, :role_names, role_names)
      payment = insert(:payment, organisation: user.organisation)
      fetched_payement = Enterprise.show_payment(payment.id, user)
      assert fetched_payement.razorpay_id == payment.razorpay_id
      assert fetched_payement.id == payment.id
      assert fetched_payement.organisation.id == payment.organisation.id
      assert fetched_payement.creator.id == payment.creator.id
      assert fetched_payement.membership.id == payment.membership.id
      assert fetched_payement.from_plan.id == payment.from_plan.id
      assert fetched_payement.to_plan.id == payment.to_plan.id
    end

    test "returns nil when payment does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      payment = insert(:payment)
      response = Enterprise.show_payment(payment.id, user)
      assert response == nil
    end

    test "returns nil for non existent payment" do
      user = insert(:user_with_organisation)
      response = Enterprise.show_payment(Ecto.UUID.generate(), user)
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Enterprise.show_payment(Ecto.UUID.generate(), nil)
      assert response == nil
    end
  end

  describe "members_index/2" do
    test "returns the list of all members of current user's organisation" do
      organisation = insert(:organisation)
      user1 = insert(:user, organisation: organisation, current_org_id: organisation.id)
      user2 = insert(:user, organisation: organisation)
      user3 = insert(:user, organisation: organisation)

      response = Enterprise.members_index(user1, %{"page" => 1})
      user_ids = response.entries |> Enum.map(fn x -> x.id end) |> to_string()

      assert user_ids =~ user1.id
      assert user_ids =~ user2.id
      assert user_ids =~ user3.id
      assert response.page_number == 1
      assert response.total_pages == 1
      assert response.total_entries == 3
    end

    test "returns the list of all members of current user's organisation matching the given name" do
      organisation = insert(:organisation)

      user1 =
        insert(:user, name: "John", organisation: organisation, current_org_id: organisation.id)

      user2 = insert(:user, organisation: organisation, name: "John Doe")
      user3 = insert(:user, organisation: organisation)

      response = Enterprise.members_index(user1, %{"page" => 1, "name" => "joh"})
      user_ids = response.entries |> Enum.map(fn x -> x.id end) |> to_string()

      assert user_ids =~ user1.id
      assert user_ids =~ user2.id
      refute user_ids =~ user3.id
      assert response.page_number == 1
      assert response.total_pages == 1
      assert response.total_entries == 2
    end
  end

  ################# <<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>####################

  @valid_vendor_attrs %{
    "name" => "vendor name",
    "email" => "vendor email",
    "phone" => "vendor phone",
    "address" => "vendor address",
    "gstin" => "vendor gstin",
    "reg_no" => "vendor reg_no",
    "contact_person" => "vendor contact_person"
  }
  @invalid_vendor_attrs %{"name" => nil, "email" => nil}

  describe "create_vendor/2" do
    test "create vendor on valid attributes" do
      user = insert(:user_with_organisation)
      count_before = Vendor |> Repo.all() |> length()
      vendor = Enterprise.create_vendor(user, @valid_vendor_attrs)
      assert count_before + 1 == Vendor |> Repo.all() |> length()
      assert vendor.name == @valid_vendor_attrs["name"]
      assert vendor.email == @valid_vendor_attrs["email"]
      assert vendor.phone == @valid_vendor_attrs["phone"]
      assert vendor.address == @valid_vendor_attrs["address"]
      assert vendor.gstin == @valid_vendor_attrs["gstin"]
      assert vendor.reg_no == @valid_vendor_attrs["reg_no"]

      assert vendor.contact_person == @valid_vendor_attrs["contact_person"]
    end

    test "create vendor on invalid attrs" do
      user = insert(:user_with_organisation)
      count_before = Vendor |> Repo.all() |> length()

      {:error, changeset} = Enterprise.create_vendor(user, @invalid_vendor_attrs)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before == count_after

      assert %{
               name: ["can't be blank"],
               email: ["can't be blank"],
               phone: ["can't be blank"],
               address: ["can't be blank"],
               gstin: ["can't be blank"],
               reg_no: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "update_vendor/2" do
    test "update vendor on valid attrs" do
      user = insert(:user)
      vendor = insert(:vendor, creator: user, organisation: user.organisation)
      count_before = Vendor |> Repo.all() |> length()

      vendor = Enterprise.update_vendor(vendor, @valid_vendor_attrs)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before == count_after
      assert vendor.name == @valid_vendor_attrs["name"]
      assert vendor.email == @valid_vendor_attrs["email"]
      assert vendor.phone == @valid_vendor_attrs["phone"]
      assert vendor.address == @valid_vendor_attrs["address"]
      assert vendor.gstin == @valid_vendor_attrs["gstin"]
      assert vendor.reg_no == @valid_vendor_attrs["reg_no"]
    end

    test "returns error on invalid attrs" do
      user = insert(:user)
      vendor = insert(:vendor, creator: user)
      count_before = Vendor |> Repo.all() |> length()

      {:error, changeset} = Enterprise.update_vendor(vendor, @invalid_vendor_attrs)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before == count_after
      assert %{name: ["can't be blank"], email: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "get_vendor/1" do
    test "get vendor returns the vendor data" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: user.organisation)
      v_vendor = Enterprise.get_vendor(user, vendor.id)
      assert v_vendor.name == vendor.name
      assert v_vendor.email == vendor.email
      assert v_vendor.phone == vendor.phone
      assert v_vendor.address == vendor.address
      assert v_vendor.gstin == vendor.gstin
      assert v_vendor.reg_no == vendor.reg_no

      assert v_vendor.contact_person == vendor.contact_person
    end

    test "get vendor from another organisation will not be possible" do
      user = insert(:user)
      vendor = insert(:vendor, creator: user)
      v_vendor = Enterprise.get_vendor(vendor.id, user)
      assert v_vendor == nil
    end
  end

  describe "show vendor" do
    test "show vendor returns the vendor data and preloads" do
      user = insert(:user_with_organisation)
      vendor = insert(:vendor, creator: user, organisation: user.organisation)
      v_vendor = Enterprise.show_vendor(vendor.id, user)
      assert v_vendor.name == vendor.name
      assert v_vendor.email == vendor.email
      assert v_vendor.phone == vendor.phone
      assert v_vendor.address == vendor.address
      assert v_vendor.gstin == vendor.gstin
      assert v_vendor.reg_no == vendor.reg_no

      assert v_vendor.contact_person == vendor.contact_person
    end
  end

  describe "delete_vendor/1" do
    test "delete vendor deletes the vendor data" do
      vendor = insert(:vendor)
      count_before = Vendor |> Repo.all() |> length()
      {:ok, v_vendor} = Enterprise.delete_vendor(vendor)
      count_after = Vendor |> Repo.all() |> length()
      assert count_before - 1 == count_after
      assert v_vendor.name == vendor.name
      assert v_vendor.email == vendor.email
      assert v_vendor.phone == vendor.phone
      assert v_vendor.address == vendor.address
      assert v_vendor.gstin == vendor.gstin
      assert v_vendor.reg_no == vendor.reg_no

      assert v_vendor.contact_person == vendor.contact_person
    end
  end

  test "vendor index lists the vendor data" do
    user = insert(:user_with_organisation)
    v1 = insert(:vendor, creator: user, organisation: user.organisation)
    v2 = insert(:vendor, creator: user, organisation: user.organisation)
    vendor_index = Enterprise.vendor_index(user, %{page_number: 1})

    assert vendor_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ v1.name
    assert vendor_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ v2.name
  end
end
