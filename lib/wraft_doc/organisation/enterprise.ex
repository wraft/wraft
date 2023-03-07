defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto.Query
  import Ecto
  alias Ecto.Multi

  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Membership
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Repo
  alias WraftDoc.TaskSupervisor
  alias WraftDoc.Workers.DefaultWorker
  alias WraftDoc.Workers.EmailWorker
  alias WraftDoc.Workers.ScheduledWorker

  @default_states [%{"state" => "Draft", "order" => 1}, %{"state" => "Publish", "order" => 2}]

  @default_controlled_states [
    %{"state" => "Draft", "order" => 1},
    %{"state" => "Review", "order" => 2},
    %{"state" => "Publish", "order" => 3}
  ]

  @trial_plan_name "Free Trial"
  @trial_duration 14
  @doc """
  Get a flow from its UUID.
  """
  @spec get_flow(binary, User.t()) :: Flow.t() | nil
  def get_flow(<<_::288>> = flow_id, %{current_org_id: org_id}) do
    case Repo.get_by(Flow, id: flow_id, organisation_id: org_id) do
      %Flow{} = flow -> flow
      _ -> {:error, :invalid_id, "Flow"}
    end
  end

  def get_flow(_, %{current_org_id: _}), do: {:error, :invalid_id, "Flow"}

  def get_flow(_, _), do: {:error, :fake}

  @doc """
  Returns initial state of a flow
  """
  def initial_state(%Flow{} = flow) do
    with %Flow{states: states} <- Repo.preload(flow, :states) do
      Enum.min_by(states, fn x -> x.order end)
    end
  end

  def initial_state(_), do: nil

  @doc """
  Get a state from its UUID and user's organisation.
  """
  @spec get_state(User.t(), Ecto.UUID.t()) :: State.t() | {:error, :invalid_id}
  def get_state(%User{current_org_id: org_id}, <<_::288>> = state_id) do
    query = from(s in State, where: s.id == ^state_id and s.organisation_id == ^org_id)

    case Repo.one(query) do
      %State{} = state -> state
      _ -> {:error, :invalid_id}
    end
  end

  def get_state(%User{current_org_id: _org_id}, _), do: {:error, :invalid_id}
  def get_state(_, <<_::288>>), do: {:error, :fake}

  @doc """
  Create a controlled flow flow.
  """
  @spec create_flow(User.t(), map) ::
          %Flow{creator: User.t()} | {:error, Ecto.Changeset.t()}

  def create_flow(%{current_org_id: org_id} = current_user, %{"controlled" => true} = params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:flows)
    |> Flow.controlled_changeset(params)
    |> Repo.insert(ex_audit_custom: [user_id: current_user.id])
    |> case do
      {:ok, flow} ->
        Task.start_link(fn -> create_default_states(current_user, flow, true) end)
        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_flow(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:flows)
    |> Flow.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, flow} ->
        Task.Supervisor.start_child(TaskSupervisor, fn ->
          create_default_states(current_user, flow)
        end)

        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_flow(_, _), do: {:error, :fake}

  @doc """
  Funtion to align order of states under  a flow
  ## Params
  * flow - Flow struct
  * params - a map with states key
  ## Example
  iex(1)> params = %{"states"=> [%{"id"=> "262sda-sdf5-dsf55-ddfs","order"=>1},%{"id"=>"12sd66-6d211f-1261d2f","order"=> 2}]}
  iex(2)> align_state(%User{},%Flow{},params)
  iex(3)> %Flow{states: [%State{},%State{}]}
  """
  def align_states(flow, params) do
    flow
    |> Flow.align_order_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, flow} -> flow
      {:error, _} = changeset -> changeset
    end
  end

  @doc """
  List of all flows.
  """
  @spec flow_index(User.t(), map) :: map
  def flow_index(%User{current_org_id: org_id}, params) do
    query =
      from(f in Flow,
        where: f.organisation_id == ^org_id,
        order_by: [desc: f.id],
        preload: [:creator]
      )

    Repo.paginate(query, params)
  end

  def flow_index(_, _), do: {:error, :fake}

  @doc """
  Show a flow.
  """
  @spec show_flow(binary, User.t()) :: Flow.t() | nil
  def show_flow(flow_id, user) do
    with %Flow{} = flow <- get_flow(flow_id, user) do
      Repo.preload(flow, [
        :creator,
        :states,
        approval_systems: [:pre_state, :post_state, :approver]
      ])
    end
  end

  @doc """
  Update a controlled flow
  """
  @spec update_flow(Flow.t(), map()) :: Flow.t() | {:error, Ecto.Changeset.t()}
  def update_flow(flow, %{"controlled" => true} = params) do
    flow
    |> Flow.update_controlled_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, flow} ->
        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  def update_flow(flow, params) do
    flow
    |> Flow.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, flow} ->
        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a  flow.
  """
  @spec delete_flow(Flow.t()) :: {:ok, Flow.t()} | {:error, Ecto.Changeset.t()}
  def delete_flow(flow) do
    flow
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :states,
      message:
        "Cannot delete the flow. Some States depend on this flow. Delete those states and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Create default states for a controlled fow
  """
  @spec create_default_states(User.t(), Flow.t(), boolean()) :: list
  def create_default_states(current_user, flow, true) do
    Enum.map(@default_controlled_states, fn x -> create_state(current_user, flow, x) end)
  end

  @doc """
  Create default states for an uncontrolled flow
  """
  def create_default_states(current_user, flow) do
    Enum.map(@default_states, fn x -> create_state(current_user, flow, x) end)
  end

  @doc """
  Create a state under a flow.
  """
  @spec create_state(User.t(), Flow.t(), map) :: State.t() | {:error, Ecto.Changeset.t()}
  def create_state(%User{current_org_id: org_id} = current_user, flow, params) do
    params = Map.merge(params, %{"organisation_id" => org_id, "flow_id" => flow.id})

    current_user
    |> build_assoc(:states)
    |> State.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, state} -> state
      {:error, _} = changeset -> changeset
    end
  end

  @doc """
  State index under a flow.
  """
  @spec state_index(binary, map) :: map
  def state_index(flow_uuid, params) do
    query =
      from(s in State,
        join: f in Flow,
        where: f.id == ^flow_uuid and s.flow_id == f.id,
        order_by: [desc: s.id],
        preload: [:flow, :creator]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Update a state.
  """
  # TODO - Missing tests
  @spec update_state(State.t(), map()) ::
          %State{creator: User.t(), flow: Flow.t()} | {:error, Ecto.Changeset.t()}
  def update_state(state, params) do
    state
    |> State.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, state} ->
        Repo.preload(state, [:creator, :flow])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Shuffle the order of flows.
  """
  @spec shuffle_order(State.t(), integer) :: list
  def shuffle_order(%{order: order, flow_id: flow_id}, additive) do
    query = from(s in State, where: s.flow_id == ^flow_id and s.order > ^order)

    query
    |> Repo.all()
    |> Task.async_stream(fn x -> update_state_order(x, additive) end)
    |> Enum.to_list()
  end

  # Update the flow order by adding the additive.
  @spec update_state_order(State.t(), integer) :: {:ok, State.t()}
  defp update_state_order(%{order: order} = state, additive) do
    state
    |> State.order_update_changeset(%{order: order + additive})
    |> Repo.update()
  end

  @doc """
  Delete a state.
  """
  @spec delete_state(State.t()) :: {:ok, State.t()} | {:error, Ecto.Changeset.t()}
  def delete_state(state) do
    state
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the state. Some contents depend on this state. Update those states and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Get an organisation from its UUID.
  """
  @spec get_organisation(binary) :: Organisation.t() | nil
  def get_organisation(id) do
    Repo.get(Organisation, id)
  end

  @doc """
  Get personal organisation from user email
  """
  @spec get_personal_org_by_email(binary) :: Organisation.t() | nil
  def get_personal_org_by_email(email) do
    Repo.get_by(Organisation, email: email, name: "Personal")
  end

  @doc """
  Create an Organisation
  """
  @spec create_organisation(User.t(), map) :: Organisation.t()
  def create_organisation(%User{} = user, params) do
    Multi.new()
    |> Multi.insert(
      :organisation,
      user |> build_assoc(:owned_organisations) |> Organisation.changeset(params)
    )
    |> Multi.update(:organisation_logo, &Organisation.logo_changeset(&1.organisation, params))
    |> Multi.insert(:user_organisation, fn %{organisation: org} ->
      UserOrganisation.changeset(%UserOrganisation{}, %{user_id: user.id, organisation_id: org.id})
    end)
    |> Multi.run(:membership, fn _repo, %{organisation: organisation} ->
      create_membership(organisation)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{organisation_logo: organisation}} -> organisation
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Create a personal organisation when the user first sign up for wraft
  """
  @spec create_personal_organisation(User.t(), map) :: Organisation.t()
  def create_personal_organisation(%User{} = user, params) do
    Multi.new()
    |> Multi.insert(
      :organisation,
      user
      |> build_assoc(:owned_organisations)
      |> Organisation.personal_organisation_changeset(params)
    )
    |> Multi.run(:membership, fn _repo, %{organisation: organisation} ->
      create_membership(organisation)
    end)
    |> Repo.transaction()
  end

  @doc """
  Update an Organisation
  """
  @spec update_organisation(Organisation.t(), map) :: {:ok, Organisation.t()}
  def update_organisation(organisation, params) do
    organisation
    |> Organisation.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, organisation} ->
        organisation

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Deletes the organisation
  """
  def delete_organisation(%Organisation{} = organisation) do
    organisation
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :users_organisations,
      message:
        "Cannot delete the organisation. Some user depend on this organisation. Update those users and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Check if a user with the given Email ID exists or not.
  """
  @spec already_member(String.t()) :: :ok | {:error, :already_member}
  def already_member(email) when is_nil(email), do: {:error, :no_data}

  def already_member(email) do
    email
    |> Account.find()
    |> case do
      %User{} ->
        {:error, :already_member}

      _ ->
        :ok
    end
  end

  @doc """
  Sends invitation email to the email with the role.
  """

  def invite_team_member(
        %User{name: name} = user,
        %{name: org_name} = organisation,
        email,
        %Role{} = role
      )
      when is_binary(email) do
    token =
      WraftDoc.create_phx_token("organisation_invite", %{
        organisation_id: organisation.id,
        email: email,
        role: role.id
      })

    Task.start_link(fn ->
      Account.insert_auth_token!(user, %{value: token, token_type: "invite"})
    end)

    %{org_name: org_name, user_name: name, email: email, token: token}
    |> EmailWorker.new(queue: "mailer", tags: ["invite"])
    |> Oban.insert()
  end

  def invite_team_member(_, _, _, _), do: {:error, :no_data}

  @doc """
  Fetches the list of all members of current users organisation.
  """
  @spec members_index(User.t(), map) :: any
  def members_index(%User{current_org_id: organisation_id}, %{"name" => name} = params) do
    query =
      from(u in User,
        where: u.organisation_id == ^organisation_id,
        where: ilike(u.name, ^"%#{name}%"),
        where: is_nil(u.deleted_at),
        preload: [:profile, :roles, :organisation]
      )

    Repo.paginate(query, params)
  end

  def members_index(%User{current_org_id: organisation_id}, params) do
    query =
      from(u in User,
        where: u.organisation_id == ^organisation_id,
        where: is_nil(u.deleted_at),
        preload: [:profile, :roles, :organisation]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Search organisation by name

  ## Parameters
  - `params` - A map of params to paginate list of organisation

  ## Examples
  organisations=list_organisations(%{"page"=>1, "name"=> "ABC Enterprices"})
  organisation.entries= [%Organisation{name: "ABC Enterprices"}]
  """

  @spec list_organisations(map) :: Scrivener.Page.t()
  def list_organisations(%{"name" => name} = params) do
    query = from(o in Organisation, where: ilike(o.name, ^"%#{name}%"))
    Repo.paginate(query, params)
  end

  def list_organisations(params) do
    Repo.paginate(Organisation, params)
  end

  @doc """
  List all the organisations for the user
  """
  @spec list_org_by_user(User.t()) :: User.t() | nil
  def list_org_by_user(user) do
    Repo.preload(user, :organisations)
  end

  @doc """
  Create approval system
  """
  @spec create_approval_system(User.t(), map) ::
          ApprovalSystem.t() | {:error, Ecto.Changeset.t()}
  def create_approval_system(%User{current_org_id: organisation_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => organisation_id})

    current_user
    |> build_assoc(:approval_systems)
    |> ApprovalSystem.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, approval_system} ->
        approval_system_preload(approval_system)

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_approval_system(_, _), do: {:error, :fake}

  @doc """
  Get approval system by uuid
  """

  @spec get_approval_system(Ecto.UUID.t(), User.t()) :: ApprovalSystem.t()
  def get_approval_system(<<_::288>> = id, %{current_org_id: org_id}) do
    query =
      from(as in ApprovalSystem,
        join: f in Flow,
        on: as.flow_id == f.id,
        where: f.organisation_id == ^org_id and as.id == ^id
      )

    case Repo.one(query) do
      %ApprovalSystem{} = approval_system -> approval_system
      _ -> {:error, :invalid_id, "ApprovalSystem"}
    end
  end

  def get_approval_system(_, %{current_org_id: _}), do: {:error, :invalid_id, "ApprovalSystem"}
  def get_approval_system(_, _), do: {:error, :fake}

  def show_approval_system(id, user) do
    with %ApprovalSystem{} = approval_system <- get_approval_system(id, user) do
      approval_system_preload(approval_system)
    end
  end

  @doc """
  Update an uproval system
  """
  @spec update_approval_system(User.t(), ApprovalSystem.t(), map) ::
          ApprovalSystem.t() | {:error, Ecto.Changeset.t()}
  def update_approval_system(%{current_org_id: org_id}, approval_system, params) do
    params = Map.put(params, "organisation_id", org_id)

    approval_system
    |> ApprovalSystem.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, approval_system} ->
        approval_system_preload(approval_system)
    end
  end

  def update_approval_system(_user, approval_system, params) do
    approval_system
    |> ApprovalSystem.changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, approval_system} ->
        approval_system
    end
  end

  defp approval_system_preload(approval_system) do
    Repo.preload(approval_system, [
      :pre_state,
      :post_state,
      :approver,
      :creator,
      :flow
    ])
  end

  @doc """
  Delete an approval system
  """
  @spec delete_approval_system(ApprovalSystem.t()) :: ApprovalSystem.t()
  def delete_approval_system(%ApprovalSystem{} = approval_system) do
    with {:ok, %ApprovalSystem{} = approval_system} <- Repo.delete(approval_system) do
      approval_system_preload(approval_system)
    end
  end

  @doc """
  Check the user and approver is same while approving the content
  """
  def same_user?(current_user_id, approver_id) when current_user_id != approver_id,
    do: :invalid_user

  def same_user?(current_user_id, approver_id) when current_user_id === approver_id,
    do: true

  @doc """
  Check the prestate of the approval system and state of instance are same
  """
  def same_state?(prestate_id, state_id) when prestate_id != state_id,
    do: :unprocessible_state

  def same_state?(prestate_id, state_id) when prestate_id === state_id, do: true

  @doc """
  Creates a plan.
  """
  @spec create_plan(map) :: {:ok, Plan.t()}
  def create_plan(params) do
    %Plan{} |> Plan.changeset(params) |> Repo.insert()
  end

  @doc """
  Get a plan from its UUID.
  """
  @spec get_plan(Ecto.UUID.t()) :: Plan.t() | nil

  def get_plan(<<_::288>> = p_id) do
    case Repo.get(Plan, p_id) do
      %Plan{} = plan -> plan
      _ -> {:error, :invalid_id, "Plan"}
    end
  end

  def get_plan(_), do: {:error, :invalid_id, "Plan"}

  @doc """
  Get all plans.
  """
  @spec plan_index() :: [Plan.t()]
  def plan_index do
    Repo.all(Plan)
  end

  @doc """
  Updates a plan.
  """
  @spec update_plan(Plan.t(), map) :: {:ok, Plan.t()} | {:error, Ecto.Changeset.t()}
  def update_plan(%Plan{} = plan, params) do
    plan |> Plan.changeset(params) |> Repo.update()
  end

  def update_plan(_, _), do: nil

  @doc """
  Deletes a plan
  """
  @spec delete_plan(Plan.t()) :: {:ok, Plan.t()} | nil
  def delete_plan(%Plan{} = plan) do
    Repo.delete(plan)
  end

  def delete_plan(_), do: nil

  # Create free trial membership for the given organisation.
  @spec create_membership(Organisation.t()) :: Membership.t()
  defp create_membership(%Organisation{id: id} = _organisation) do
    plan = Repo.get_by(Plan, name: @trial_plan_name)
    start_date = Timex.now()
    end_date = find_end_date(start_date, @trial_duration)
    params = %{start_date: start_date, end_date: end_date, plan_duration: @trial_duration}

    plan
    |> build_assoc(:memberships, organisation_id: id)
    |> Membership.changeset(params)
    |> Repo.insert!()
    |> case do
      %Membership{} = membership -> {:ok, membership}
      changeset -> {:error, changeset}
    end
  end

  # Find the end date of a membership from the start date and duration of the
  # membership.
  @spec find_end_date(DateTime.t(), integer) :: DateTime.t() | nil
  defp find_end_date(start_date, duration) when is_integer(duration) do
    Timex.shift(start_date, days: duration)
  end

  defp find_end_date(_, _), do: nil

  @doc """
  Gets a membership from its UUID.
  """
  def get_membership(<<_::288>> = m_id), do: Repo.get(Membership, m_id)

  def get_membership(_), do: nil

  @doc """
  Same as get_membership/1, but also uses user's current organisation ID to get the membership.
  """
  @spec get_membership(Ecto.UUID.t(), User.t()) :: Membership.t() | nil
  def get_membership(<<_::288>> = m_id, %{current_org_id: org_id}) do
    Repo.get_by(Membership, id: m_id, organisation_id: org_id)
  end

  def get_membership(_, _), do: nil

  @doc """
  Get membership of an organisation with the given UUID.
  """
  @spec get_organisation_membership(Ecto.UUID.t()) :: Membership.t() | nil
  def get_organisation_membership(<<_::288>> = o_uuid) do
    query =
      from(m in Membership,
        join: o in Organisation,
        on: o.id == m.organisation_id,
        where: o.id == ^o_uuid,
        preload: [:plan]
      )

    Repo.one(query)
  end

  def get_organisation_membership(_), do: {:error, :invalid_id, "Organisation"}

  @doc """
  Updates a membership.
  """
  @spec update_membership(User.t(), Membership.t(), Plan.t(), Razorpay.Payment.t()) ::
          Membership.t() | {:ok, Payment.t()} | {:error, :wrong_amount} | nil
  def update_membership(
        %User{} = user,
        %Membership{} = membership,
        %Plan{} = plan,
        %Razorpay.Payment{status: "failed"} = razorpay
      ) do
    params = create_payment_params(membership, plan, razorpay)
    user |> create_payment_changeset(params) |> Repo.insert()
  end

  def update_membership(
        %User{} = user,
        %Membership{} = membership,
        %Plan{} = plan,
        %Razorpay.Payment{amount: amount} = razorpay
      ) do
    case get_duration_from_plan_and_amount(plan, amount) do
      duration when is_integer(duration) ->
        params = create_membership_and_payment_params(membership, plan, duration, razorpay)
        do_update_membership(user, membership, params)

      error ->
        error
    end
  end

  def update_membership(%User{}, %Membership{}, %Plan{}, _), do: {:error, :invalid_id, "RazorPay"}
  def update_membership(_, _, _, _), do: {:error, :invalid_data}

  # Update the membership and insert a new payment.
  @spec do_update_membership(User.t(), Membership.t(), map) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  defp do_update_membership(user, membership, params) do
    Multi.new()
    |> Multi.update(:membership, Membership.update_changeset(membership, params))
    |> Multi.insert(:payment, create_payment_changeset(user, params))
    |> Repo.transaction()
    |> case do
      {:error, _, changeset, _} ->
        {:error, changeset}

      {:ok, %{membership: membership, payment: payment}} ->
        membership = Repo.preload(membership, [:plan, :organisation])

        Task.start_link(fn -> create_invoice(membership, payment) end)
        Task.start_link(fn -> create_membership_expiry_check_job(membership) end)

        membership
    end
  end

  # Create new payment.
  @spec create_payment_changeset(User.t(), map) :: Ecto.Changeset.t()
  defp create_payment_changeset(user, params) do
    user
    |> build_assoc(:payments, organisation_id: user.current_org_id)
    |> Payment.changeset(params)
  end

  # Create membership and payment params
  @spec create_membership_and_payment_params(
          Membership.t(),
          Plan.t(),
          integer(),
          Razorpay.Payment.t()
        ) :: map
  defp create_membership_and_payment_params(membership, plan, duration, razorpay) do
    start_date = Timex.now()
    end_date = find_end_date(start_date, duration)

    membership
    |> create_payment_params(plan, razorpay)
    |> Map.merge(%{
      start_date: start_date,
      end_date: end_date,
      plan_duration: duration,
      plan_id: plan.id
    })
  end

  # Create payment params
  @spec create_payment_params(Membership.t(), Plan.t(), Razorpay.Payment.t()) :: map
  defp create_payment_params(
         membership,
         plan,
         %Razorpay.Payment{amount: amount, id: r_id, status: status} = razorpay
       ) do
    status = String.to_atom(status)
    status = Payment.statuses()[status]

    membership = Repo.preload(membership, [:plan])
    action = get_payment_action(membership.plan, plan)

    %{
      razorpay_id: r_id,
      amount: amount,
      status: status,
      action: action,
      from_plan_id: membership.plan_id,
      to_plan_id: plan.id,
      meta: razorpay,
      membership_id: membership.id
    }
  end

  # Gets the duration of selected plan based on the amount paid.
  @spec get_duration_from_plan_and_amount(Plan.t(), integer()) ::
          integer() | {:error, :wrong_amount}
  defp get_duration_from_plan_and_amount(%Plan{yearly_amount: amount}, amount), do: 365
  defp get_duration_from_plan_and_amount(%Plan{monthly_amount: amount}, amount), do: 30
  defp get_duration_from_plan_and_amount(_, _), do: {:error, :wrong_amount}

  # Gets the payment action comparing the old and new plans.
  @spec get_payment_action(Plan.t(), Plan.t()) :: integer
  defp get_payment_action(%Plan{id: id}, %Plan{id: id}) do
    Payment.actions()[:renew]
  end

  defp get_payment_action(%Plan{} = old_plan, %Plan{} = new_plan) do
    cond do
      old_plan.yearly_amount > new_plan.yearly_amount ->
        Payment.actions()[:downgrade]

      old_plan.yearly_amount < new_plan.yearly_amount ->
        Payment.actions()[:upgrade]
    end
  end

  # Create invoice and update payment.
  @spec create_invoice(Membership.t(), Payment.t()) :: {:ok, Payment.t()} | Ecto.Changeset.t()
  defp create_invoice(membership, payment) do
    invoice_number = generate_invoice_number(payment)

    invoice =
      Phoenix.View.render_to_string(
        WraftDocWeb.Api.V1.PaymentView,
        "invoice.html",
        membership: membership,
        invoice_number: invoice_number,
        payment: payment
      )

    {:ok, filename} =
      PdfGenerator.generate(invoice,
        page_size: "A4",
        delete_temporary: true,
        edit_password: "1234",
        filename: invoice_number
      )

    invoice = invoice_upload_struct(invoice_number, filename)

    upload_invoice(payment, invoice, invoice_number)
  end

  # Creates a background job that checks if the membership is expired on the date of membership expiry
  @spec create_membership_expiry_check_job(Membership.t()) :: Oban.Job.t()
  defp create_membership_expiry_check_job(%Membership{id: id, end_date: end_date}) do
    %{membership_id: id}
    |> ScheduledWorker.new(scheduled_at: end_date, tags: ["plan_expiry"])
    |> Oban.insert!()
  end

  # Create invoice number from payment ID.
  defp generate_invoice_number(%{id: id}) do
    "WraftDoc-Invoice-" <> String.pad_leading("#{id}", 6, "0")
  end

  # Plug upload struct for uploading invoice
  defp invoice_upload_struct(invoice_number, filename) do
    %Plug.Upload{
      content_type: "application/pdf",
      filename: "#{invoice_number}.pdf",
      path: filename
    }
  end

  # Upload the invoice to AWS and link with payment transactions.
  defp upload_invoice(payment, invoice, invoice_number) do
    params = %{invoice: invoice, invoice_number: invoice_number}
    payment |> Payment.invoice_changeset(params) |> Repo.update!()
  end

  @doc """
  Gets the razorpay payment struct from the razorpay ID using `Razorpay.Payment.get/2`
  """
  @spec get_razorpay_data(binary) :: {:ok, Razorpay.Payment.t()} | Razorpay.error()
  def get_razorpay_data(razorpay_id) do
    Razorpay.Payment.get(razorpay_id)
  end

  @doc """
  Payment index with pagination.
  """
  @spec payment_index(integer, map) :: map
  def payment_index(org_id, params) do
    query =
      from(p in Payment,
        where: p.organisation_id == ^org_id,
        preload: [:organisation, :creator],
        order_by: [desc: p.id]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Get a payment from its UUID.
  """

  # @spec get_payment(Ecto.UUID.t(), User.t()) :: Payment.t() | nil

  # def get_payment(payment_id, %{role_names: role_names, organisation_id: org_id}) do
  #   if Enum.member?(role_names, "super_admin") do
  #     Repo.get_by(Payment, id: payment_id)
  #   else
  #     Repo.get_by(Payment, id: payment_id, organisation_id: org_id)
  #   end
  # end

  @spec get_payment(Ecto.UUID.t(), User.t()) :: Payment.t() | nil
  def get_payment(payment_id, %{role: %{name: "super_admin"}}) do
    Repo.get_by(Payment, id: payment_id)
  end

  def get_payment(payment_id, %{current_org_id: org_id}) do
    Repo.get_by(Payment, id: payment_id, organisation_id: org_id)
  end

  def get_payment(_, _), do: nil

  @doc """
  Show a payment.
  """
  @spec show_payment(Ecto.UUID.t(), User.t()) :: Payment.t() | nil
  def show_payment(payment_id, user) do
    payment_id
    |> get_payment(user)
    |> Repo.preload([:organisation, :creator, :membership, :from_plan, :to_plan])
  end

  @doc """
  Create a vendor under organisations
  ##Parameters
  - `current_user` - an User struct
  - `params` - a map countains vendor parameters

  """
  @spec create_vendor(User.t(), map) :: Vendor.t() | {:error, Ecto.Changeset.t()}
  def create_vendor(current_user, params) do
    current_user
    |> build_assoc(:vendors, organisation_id: current_user.current_org_id)
    |> Vendor.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, vendor} ->
        Repo.preload(vendor, [:organisation, :creator])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Retunrs vendor by id and organisation
  ##Parameters
  -`uuid`- UUID of vendor
  -`organisation`- Organisation struct

  """
  @spec get_vendor(Organisation.t(), Ecto.UUID.t()) :: Vendor.t()
  def get_vendor(%User{current_org_id: org_id}, id) do
    query = from(v in Vendor, where: v.id == ^id and v.organisation_id == ^org_id)

    case Repo.one(query) do
      %Vendor{} = vendor -> vendor
      _ -> {:error, :invalid_id, "Vendor"}
    end
  end

  def get_vendor(_, _), do: nil

  @spec show_vendor(Ecto.UUID.t(), User.t()) :: Vendor.t()
  def show_vendor(id, user) do
    with %Vendor{} = vendor <- get_vendor(user, id) do
      Repo.preload(vendor, [:creator, :organisation])
    end
  end

  @doc """
  To update vendor details and attach logo file

  ## Parameters
  -`vendor`- a Vendor struct
  -`params`- a map contains vendor fields
  """
  def update_vendor(vendor, params) do
    vendor
    |> Vendor.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, vendor} ->
        Repo.preload(vendor, [:organisation, :creator])
    end
  end

  @doc """
  Deletes vendor data
  ##Parameters
  -`vendor`- a Vendor struct
  """
  @spec delete_vendor(Vendor.t()) :: Vendor.t()
  def delete_vendor(%Vendor{} = vendor), do: Repo.delete(vendor)

  @doc """
  Lists all vendors under an organisation
  -`organisation`- an Organisation struct
  -`params` - a map contains params for pagination
  """
  @spec vendor_index(Organisation.t(), map()) :: Scrivener.Paginater.t()
  def vendor_index(%User{current_org_id: organisation_id}, params) do
    query = from(v in Vendor, where: v.organisation_id == ^organisation_id)
    Repo.paginate(query, params)
  end

  def vendor_index(_, _), do: nil

  # TODO - Not required
  @doc """
  Lists all pending approval systems to approve
  ## Parameters
  * user- User struct
  """
  @spec get_pending_approvals(User.t(), map()) :: Scrivener.Page.t()
  def get_pending_approvals(%User{id: id, current_org_id: org_id}, params) do
    query =
      from(as in ApprovalSystem,
        where: as.approver_id == ^id,
        where: as.approved == false,
        where: as.organisation_id == ^org_id,
        preload: [:instance, :pre_state, :post_state, :approver]
      )

    Repo.paginate(query, params)
  end

  def get_pending_approvals(_, _), do: nil

  def list_approval_systems(%User{current_org_id: org_id}, params) do
    query =
      from(as in ApprovalSystem,
        join: f in Flow,
        on: as.flow_id == f.id,
        where: f.organisation_id == ^org_id,
        preload: [:pre_state, :post_state, :approver, :flow]
      )

    Repo.paginate(query, params)
  end

  def roles_in_users_organisation(%User{current_org_id: organisation_id}) do
    query = from(r in Role, where: r.organisation_id == ^organisation_id)

    Repo.all(query)
  end

  @doc """
  Creates a default worker job
  """
  @spec create_default_worker_job(map(), binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def create_default_worker_job(args, tag) do
    args
    |> DefaultWorker.new(tags: [tag])
    |> Oban.insert()
  end
end
