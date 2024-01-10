defmodule WraftDoc.EnterpriseTest do
  use WraftDoc.DataCase, async: true

  import Mox
  @moduletag :enterprise

  alias WraftDoc.Account.Role
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Repo

  setup :verify_on_exit!

  @valid_razorpay_id "pay_EvM3nS0jjqQMyK"
  @failed_razorpay_id "pay_EvMEpdcZ5HafEl"
  test "get flow returns flow data by id" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))
    r_flow = Enterprise.get_flow(flow.id, user)
    assert flow.name == r_flow.name
  end

  test "get state returns states data " do
    user = insert(:user_with_organisation)
    state = insert(:state, organisation: List.first(user.owned_organisations))
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

  describe "flow_index/2" do
    test "flow index returns the list of flows" do
      user = insert(:user_with_organisation)
      f1 = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))
      f2 = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

      flow_index = Enterprise.flow_index(user, %{page_number: 1})

      assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f1.name
      assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f2.name
    end

    test "return error for invalid input" do
      flow_index = Enterprise.flow_index("invalid", "invalid")
      assert flow_index == {:error, :fake}
    end

    test "filter by name" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          name: "First Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          name: "Second Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"name" => "First", page_number: 1})

      assert flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f1.name
      refute flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f2.name
    end

    test "return an empty list when there are no matches for the name keyword" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          name: "First Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          name: "Second Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"name" => "does not exist", page_number: 1})

      refute flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f1.name
      refute flow_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ f2.name
    end

    test "sort by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          name: "First Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          name: "Second Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"sort" => "name", page_number: 1})

      assert List.first(flow_index.entries).name == f1.name
      assert List.last(flow_index.entries).name == f2.name
    end

    test "sort by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          name: "First Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          name: "Second Flow",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"sort" => "name_desc", page_number: 1})

      assert List.first(flow_index.entries).name == f2.name
      assert List.last(flow_index.entries).name == f1.name
    end

    test "sort by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(flow_index.entries).name == f1.name
      assert List.last(flow_index.entries).name == f2.name
    end

    test "sort by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(flow_index.entries).name == f2.name
      assert List.last(flow_index.entries).name == f1.name
    end

    test "sort by updated_at in ascending order when sort key is updated_at" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          updated_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          updated_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"sort" => "updated_at", page_number: 1})

      assert List.first(flow_index.entries).name == f1.name
      assert List.last(flow_index.entries).name == f2.name
    end

    test "sort by updated_at in descending order when sort key is updated_at_desc" do
      user = insert(:user_with_organisation)

      f1 =
        insert(:flow,
          updated_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      f2 =
        insert(:flow,
          updated_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      flow_index = Enterprise.flow_index(user, %{"sort" => "updated_at_desc", page_number: 1})

      assert List.first(flow_index.entries).name == f2.name
      assert List.last(flow_index.entries).name == f1.name
    end
  end

  test "show flow preloads flow with creator and states" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))
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
    [organisation] = user.owned_organisations
    flow = insert(:flow, creator: user, organisation: organisation)
    state = insert(:state, creator: user, organisation: organisation, flow: flow)
    count_before = State |> Repo.all() |> length()
    {:ok, d_state} = Enterprise.delete_state(state)
    count_after = State |> Repo.all() |> length()

    assert count_before - 1 == count_after
    assert state.state == d_state.state
  end

  describe "get_organisation/1" do
    test "returns the organisation by id" do
      organisation = insert(:organisation)
      g_organisation = Enterprise.get_organisation(organisation.id)
      assert organisation.name == g_organisation.name
    end

    test "returns nil if the organisation does not exist" do
      assert is_nil(Enterprise.get_organisation(Ecto.UUID.generate()))
    end
  end

  describe "get_organisation_with_member_count/1" do
    test "returns the organisation by id if members count is 0" do
      organisation = insert(:organisation)
      g_organisation = Enterprise.get_organisation_with_member_count(organisation.id)
      assert organisation.name == g_organisation.name
      assert g_organisation.members_count == 0
    end

    test "get organisation returns the organisation by id" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)
      g_organisation = Enterprise.get_organisation_with_member_count(organisation.id)
      assert organisation.name == g_organisation.name
      assert g_organisation.members_count == 1
    end

    test "returns nil if the organisation does not exist" do
      assert is_nil(Enterprise.get_organisation_with_member_count(Ecto.UUID.generate()))
    end
  end

  test "get_personal_organisation_and_role returns personal organisation and the user's role in the organisation" do
    user = insert(:user_with_personal_organisation)
    [organisation] = user.owned_organisations
    role = insert(:role, organisation: organisation)
    insert(:user_role, user: user, role: role)

    %{organisation: personal_org, user: user_with_role} =
      Enterprise.get_personal_organisation_and_role(user)

    assert "Personal" == organisation.name
    assert personal_org.id == organisation.id
    assert user.email == personal_org.email
    assert user.current_org_id == personal_org.id
    assert [%Role{name: "superadmin"}] = user_with_role.roles
  end

  describe "get_roles_by_organisation/2" do
    test "returns all roles of the user for an organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      for name <- ["admin", "editor"] do
        role = insert(:role, name: name, organisation: organisation)
        insert(:user_role, user: user, role: role)
        role
      end

      user = Enterprise.get_roles_by_organisation(user, organisation.id)
      assert 2 = Enum.count(user.roles)
      assert Enum.map(user.roles, & &1.name) == ["admin", "editor"]
    end
  end

  describe "create_organisation/2" do
    test "create organisation on valid attributes" do
      user = insert(:user)

      params = %{
        "name" => "ACC Sru",
        "legal_name" => "Acc sru pvt ltd",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "url" => "wraftdoc@customprofile.com",
        "gstin" => "32SDFASDF65SD6F",
        "logo" => %Plug.Upload{
          content_type: "image/png",
          path: File.cwd!() <> "/priv/static/images/avatar.png",
          filename: "avatar.png"
        }
      }

      organisation = Enterprise.create_organisation(user, params)

      assert organisation.id
      assert organisation.name == params["name"]
      assert organisation.legal_name == params["legal_name"]
      assert organisation.url == params["url"]
      assert organisation.logo.file_name == params["logo"].filename
    end

    test "returns error on logo file size limit exceeded over 1 MB" do
      user = insert(:user)

      params = %{
        "name" => "ACC Sru",
        "legal_name" => "Acc sru pvt ltd",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "url" => "wraftdoc@customprofile.com",
        "gstin" => "32SDFASDF65SD6F",
        "logo" => %Plug.Upload{
          content_type: "image/jpg",
          path: File.cwd!() <> "/priv/static/images/over_limit_sized_image.jpg",
          filename: "over_limit_sized_image.jpg"
        }
      }

      {:error, changeset} = Enterprise.create_organisation(user, params)

      refute changeset.valid?
      assert %{logo: ["is invalid"]} == errors_on(changeset)
    end

    test "returns error on creator_id is nil" do
      user = Map.put(insert(:user), :id, nil)

      params = %{
        "name" => "ACC Sru",
        "legal_name" => "Acc sru pvt ltd",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "gstin" => "32SDFASDF65SD6F"
      }

      {:error, changeset} = Enterprise.create_organisation(user, params)

      assert %{creator_id: ["can't be blank"]} == errors_on(changeset)
    end

    test "returns error on creating an organisation with same name" do
      user = insert(:user)

      params = %{
        "name" => "ACC Sru",
        "legal_name" => "Acc sru pvt ltd",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "gstin" => "32SDFASDF65SD6F"
      }

      Enterprise.create_organisation(user, params)

      params_new = %{
        "name" => "ACC Sru",
        "legal_name" => "Acc sru pvt",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "gstin" => "32SDFASDF65SD6G"
      }

      {:error, changeset} = Enterprise.create_organisation(user, params_new)

      assert %{name: ["organisation name already exist"]} == errors_on(changeset)
    end

    test "returns error on creating organisation with duplicate occurrence of legal name" do
      user = insert(:user)

      params = %{
        "name" => "Organisation 1",
        "legal_name" => "Organisation Legal Name",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "gstin" => "32SDFASDF65SD6F"
      }

      Enterprise.create_organisation(user, params)

      params_new = %{
        "name" => "Organisation 2",
        "legal_name" => "Organisation Legal Name",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "gstin" => "32SDFASDF65SD6G"
      }

      {:error, changeset} = Enterprise.create_organisation(user, params_new)

      assert %{legal_name: ["Organisation Already Registered."]} == errors_on(changeset)
    end

    test "returns error on creating organisation with name Personal" do
      user = insert(:user)

      params = %{
        "name" => "Personal",
        "legal_name" => "Acc sru pvt ltd",
        "email" => "dikku@kodappalaya.com",
        "address" => "Kodappalaya dikku estate",
        "gstin" => "32SDFASDF65SD6F"
      }

      count_before = Organisation |> Repo.all() |> length()

      {:error, changeset} = Enterprise.create_organisation(user, params)

      count_after = Organisation |> Repo.all() |> length()

      assert count_before == count_after
      assert %{name: ["The name 'Personal' is not allowed."]} == errors_on(changeset)
    end
  end

  describe "create_personal_organisation/2" do
    test "creates organisation on valid attributes" do
      user = insert(:user)

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

  describe "update_organisation/2" do
    test "successfully updates organisation" do
      organisation = insert(:organisation, creator: insert(:user))
      count_before = Organisation |> Repo.all() |> length()

      {:ok, organisation} =
        Enterprise.update_organisation(organisation, %{
          "name" => "Abc enterprices",
          "legal_name" => "Abc pvt ltd",
          "url" => "wraftdoc@customprofile.com"
        })

      assert count_before == Organisation |> Repo.all() |> length()
      assert organisation.name == "Abc enterprices"
      assert organisation.url == "wraftdoc@customprofile.com"
    end

    # TODO Add test for updating logo of the organistion
  end

  describe "delete_organisation/1" do
    test "returns error tuple when attempting to delete 'Personal' org" do
      organisation = insert(:organisation, name: "Personal")

      assert {:error, :no_permission} = Enterprise.delete_organisation(organisation)
    end

    test "deletes the given organisation" do
      organisation = insert(:organisation)
      count_before = Organisation |> Repo.all() |> length()
      {:ok, d_organisation} = Enterprise.delete_organisation(organisation)
      count_after = Organisation |> Repo.all() |> length()

      assert count_before - 1 == count_after
      assert organisation.name == d_organisation.name
    end
  end

  describe "create_approval_system/2" do
    test "create approval system on valid attributes" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pre_state = insert(:state, organisation: organisation)
      post_state = insert(:state, organisation: organisation)
      approver = insert(:user)
      insert(:user_organisation, user: approver, organisation: organisation)
      flow = insert(:flow, organisation: organisation)

      count_before = ApprovalSystem |> Repo.all() |> length()

      params = %{
        "pre_state_id" => pre_state.id,
        "post_state_id" => post_state.id,
        "approver_id" => approver.id,
        "flow_id" => flow.id
      }

      approval_system = Enterprise.create_approval_system(user, params)

      count_after = ApprovalSystem |> Repo.all() |> length()

      assert %ApprovalSystem{} = approval_system
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
             } = errors_on(approval_system)
    end
  end

  test "show approval system returns apprval system data" do
    user = insert(:user_with_organisation)
    flow = insert(:flow, creator: user, organisation: List.first(user.owned_organisations))

    %{id: id, flow: flow, pre_state: _pre_state} =
      insert(:approval_system, creator: user, flow: flow)

    approval_system = Enterprise.show_approval_system(id, user)
    assert approval_system.flow.id == flow.id
  end

  test "update approval system updates a system" do
    user = insert(:user_with_organisation)
    [organisation] = user.owned_organisations
    flow = insert(:flow, creator: user, organisation: organisation)

    pre_state = insert(:state, creator: user, organisation: organisation)
    post_state = insert(:state, creator: user, organisation: organisation)

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

  describe "already_member/2" do
    test "already a member return error for existing email" do
      user = insert(:user_with_organisation)

      user_org =
        insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))

      assert Enterprise.already_member(user_org.organisation_id, user.email) ==
               {:error, :already_member}
    end

    test "returns :ok if the user is removed from the organisation" do
      user = insert(:user_with_organisation)

      user_org =
        insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))

      Enterprise.remove_user(user_org)
      assert Enterprise.already_member(user_org.organisation.id, user.email) == :ok
    end

    test "already a member return ok for email does not exist" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      assert Enterprise.already_member(organisation.id, "kdgasd@gami.com") == :ok
    end
  end

  describe "invite_team_member/2" do
    test "invite member sends a email to invite a member and returns an oban job" do
      user = insert(:user_with_organisation)
      role = insert(:role)
      to_email = "myemail@app.com"

      {:ok, oban_job} =
        Enterprise.invite_team_member(user, List.first(user.owned_organisations), to_email, role)

      assert oban_job.args.email == to_email
    end

    test "invite member creates an auth token of type invite" do
      user = insert(:user_with_organisation)
      role = insert(:role)
      to_email = "myemail@app.com"
      [organisation] = user.owned_organisations
      auth_token_count = AuthToken |> Repo.all() |> length()
      Enterprise.invite_team_member(user, organisation, to_email, role)
      assert AuthToken |> Repo.all() |> length() == auth_token_count + 1
    end
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
      # We have inserted Free trial plan as part of migration
      assert length(plans) == 3
      assert plan_names =~ p1.name
      assert plan_names =~ p2.name
    end

    test "returns empty list when there are no plans" do
      Repo.delete_all(Plan)
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
      membership = insert(:membership, organisation: List.first(user.owned_organisations))
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

      success_payment_details = %{
        "status" => "captured",
        "amount" => 100_000,
        "id" => @valid_razorpay_id
      }

      new_membership =
        Enterprise.update_membership(user, membership, plan, success_payment_details)

      assert payment_count + 1 == Payment |> Repo.all() |> length
      assert new_membership.organisation_id == membership.organisation_id
      assert new_membership.plan_id == plan.id
    end

    test "does not update membership but creates new payment with failed razorpay id but valid attrs" do
      user = insert(:user_with_organisation)
      membership = insert(:membership, organisation: List.first(user.owned_organisations))
      plan = insert(:plan, monthly_amount: 100_000)
      payment_count = Payment |> Repo.all() |> length

      failed_payment_details = %{
        "id" => @failed_razorpay_id,
        "status" => "failed",
        "amount" => 100_000
      }

      {:ok, payment} =
        Enterprise.update_membership(user, membership, plan, failed_payment_details)

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

      invalid_payment_details = %{
        "code" => "BAD_REQUEST_ERROR",
        "description" => "The id provided does not exist",
        "metadata" => %{},
        "reason" => "input_validation_failed",
        "source" => "business",
        "step" => "payment_initiation"
      }

      payment_count = Payment |> Repo.all() |> length
      response = Enterprise.update_membership(user, membership, plan, invalid_payment_details)

      assert payment_count == Payment |> Repo.all() |> length
      assert response == {:error, :invalid_id, "RazorPay"}
    end

    test "does not update membership and returns wrong amount error when razorpay amount does not match any plan amount" do
      user = insert(:user_with_organisation)
      membership = insert(:membership)
      plan = insert(:plan)

      success_payment_details = %{
        "status" => "captured",
        "amount" => 100_000,
        "id" => @valid_razorpay_id
      }

      payment_count = Payment |> Repo.all() |> length
      response = Enterprise.update_membership(user, membership, plan, success_payment_details)

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
      payment = insert(:payment, organisation: List.first(user.owned_organisations))
      fetched_payment = Enterprise.get_payment(payment.id, user)
      assert fetched_payment.razorpay_id == payment.razorpay_id
      assert fetched_payment.id == payment.id
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
      payment = insert(:payment, organisation: List.first(user.owned_organisations))
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
      user1 = insert(:user, current_org_id: organisation.id)
      user2 = insert(:user)
      user3 = insert(:user)

      insert(:user_organisation, user: user1, organisation: organisation)
      insert(:user_organisation, user: user2, organisation: organisation)
      insert(:user_organisation, user: user3, organisation: organisation)

      response = Enterprise.members_index(user1, %{"page" => 1})
      user_ids = response.entries |> Enum.map(fn x -> x.id end) |> to_string()

      assert user_ids =~ user1.id
      assert user_ids =~ user2.id
      assert user_ids =~ user3.id
      assert response.page_number == 1
      assert response.total_pages == 1
      assert response.total_entries == 3
    end

    test "returns the list of all members of current user's organisation except the ones who are removed" do
      organisation = insert(:organisation)
      user1 = insert(:user, current_org_id: organisation.id)
      user2 = insert(:user)
      user3 = insert(:user)

      insert(:user_organisation, user: user1, organisation: organisation)
      insert(:user_organisation, user: user2, organisation: organisation)
      user_org = insert(:user_organisation, user: user3, organisation: organisation)

      Enterprise.remove_user(user_org)

      response = Enterprise.members_index(user1, %{"page" => 1})
      user_ids = response.entries |> Enum.map(fn x -> x.id end) |> to_string()

      assert user_ids =~ user1.id
      assert user_ids =~ user2.id
      refute user_ids =~ user3.id
      assert response.page_number == 1
      assert response.total_pages == 1
      assert response.total_entries == 2
    end

    test "returns the list of all members of current user's organisation matching the given name" do
      organisation = insert(:organisation)

      user1 = insert(:user, name: "John", current_org_id: organisation.id)

      user2 = insert(:user, name: "John Doe")
      user3 = insert(:user)

      insert(:user_organisation, user: user1, organisation: organisation)
      insert(:user_organisation, user: user2, organisation: organisation)
      insert(:user_organisation, user: user3, organisation: organisation)

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
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
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
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
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
      vendor = insert(:vendor, creator: user, organisation: List.first(user.owned_organisations))
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
    [organisation] = user.owned_organisations
    v1 = insert(:vendor, creator: user, organisation: organisation)
    v2 = insert(:vendor, creator: user, organisation: organisation)
    vendor_index = Enterprise.vendor_index(user, %{page_number: 1})

    assert vendor_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ v1.name
    assert vendor_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ v2.name
  end

  describe "list_org_by_user/1" do
    test "return user struct with all organisations the user has joined" do
      user = insert(:user)
      personal_org = insert(:organisation, name: "Personal")
      invited_org = insert(:organisation, name: "Invited Org")
      insert(:user_organisation, user: user, organisation: personal_org)
      insert(:user_organisation, user: user, organisation: invited_org)

      returned_user = Enterprise.list_org_by_user(user)

      assert Enum.member?(returned_user.organisations, personal_org) == true
      assert Enum.member?(returned_user.organisations, invited_org) == true
      assert length(returned_user.organisations) == 2
    end

    test "returns the list of the user's organisations unless they are removed" do
      user = insert(:user)
      personal_org = insert(:organisation, name: "Personal")
      invited_org = insert(:organisation, name: "Invited Org")
      insert(:user_organisation, user: user, organisation: personal_org)

      insert(:user_organisation,
        user: user,
        organisation: invited_org,
        deleted_at: DateTime.utc_now()
      )

      returned_user = Enterprise.list_org_by_user(user)

      assert Enum.member?(returned_user.organisations, personal_org) == true
      assert Enum.member?(returned_user.organisations, invited_org) == false
      assert length(returned_user.organisations) == 1
    end
  end

  describe "roles_in_users_organisation/1" do
    test "returns all roles in user's current organisation" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      role1 = insert(:role, name: "Editor", organisation: organisation)
      role2 = insert(:role, name: "Admin", organisation: organisation)

      roles_index_by_org = Enterprise.roles_in_users_organisation(user, %{})

      roles = roles_index_by_org |> Enum.map(fn x -> x.name end) |> List.to_string()

      assert roles =~ role1.name
      assert roles =~ role2.name
    end

    test "returns roles which are only part of the user's current organisation" do
      user = insert(:user_with_organisation)

      role1 = insert(:role, name: "Editor", organisation: List.first(user.owned_organisations))
      role2 = insert(:role, name: "Admin")

      roles_index_by_org = Enterprise.roles_in_users_organisation(user, %{})

      roles = roles_index_by_org |> Enum.map(fn x -> x.name end) |> List.to_string()

      assert roles =~ role1.name
      refute roles =~ role2.name
    end

    test "returns empty list if there are no roles in the user's current organisation" do
      user = insert(:user_with_organisation)
      assert [] == Enterprise.roles_in_users_organisation(user, %{})
    end

    test "filter by name" do
      user = insert(:user_with_organisation)

      role1 = insert(:role, name: "Editor", organisation: List.first(user.owned_organisations))
      role2 = insert(:role, name: "Admin", organisation: List.first(user.owned_organisations))

      roles_index_by_org = Enterprise.roles_in_users_organisation(user, %{"name" => "Edi"})

      roles = roles_index_by_org |> Enum.map(fn x -> x.name end) |> List.to_string()

      assert roles =~ role1.name
      refute roles =~ role2.name
    end

    test "returns an empty list when there are no matches for name keyword" do
      user = insert(:user_with_organisation)

      insert(:role, name: "Editor", organisation: List.first(user.owned_organisations))
      insert(:role, name: "Admin", organisation: List.first(user.owned_organisations))

      assert [] == Enterprise.roles_in_users_organisation(user, %{"name" => "does not exist"})
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)

      role1 = insert(:role, name: "Admin", organisation: List.first(user.owned_organisations))
      role2 = insert(:role, name: "Editor", organisation: List.first(user.owned_organisations))

      roles_index_by_org = Enterprise.roles_in_users_organisation(user, %{"sort" => "name"})

      assert List.first(roles_index_by_org).name == role1.name
      assert List.last(roles_index_by_org).name == role2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)

      role1 = insert(:role, name: "Admin", organisation: List.first(user.owned_organisations))
      role2 = insert(:role, name: "Editor", organisation: List.first(user.owned_organisations))

      roles_index_by_org = Enterprise.roles_in_users_organisation(user, %{"sort" => "name_desc"})

      assert List.first(roles_index_by_org).name == role2.name
      assert List.last(roles_index_by_org).name == role1.name
    end
  end

  describe "remove_user/2" do
    test "add deleted_at from the organisation" do
      user = insert(:user_with_organisation)

      user_org =
        insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))

      {:ok, organisation} = Enterprise.remove_user(user_org)
      refute organisation.deleted_at == nil
    end
  end

  describe "join_org_by_invite/2" do
    test "user can join organisation by invite" do
      user = insert(:user)
      organisation = insert(:organisation)
      role = insert(:role, name: "user", organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: user.email,
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")

      {:ok, %{organisations: returned_organisation}} = Enterprise.join_org_by_invite(user, token)
      assert returned_organisation == organisation
      assert Enterprise.already_member(organisation.id, user.email) == {:error, :already_member}
    end

    test "return error for invalid token" do
      user = insert(:user)
      organisation_id = Ecto.UUID.generate()

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation_id,
          email: "invalid@email.com",
          role: Ecto.UUID.generate()
        })

      insert(:auth_token, value: token, token_type: "invite")

      {:error, error} = Enterprise.join_org_by_invite(user, token)

      assert error == :no_permission
      assert Enterprise.already_member(organisation_id, user.email) == :ok
    end
  end
end
