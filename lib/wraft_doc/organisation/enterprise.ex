defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto.Query
  import Ecto
  alias Ecto.Multi

  alias WraftDoc.{
    Account,
    Account.User,
    Document,
    Document.Instance,
    Enterprise.ApprovalSystem,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Enterprise.Membership,
    Enterprise.Membership.Payment,
    Enterprise.Organisation,
    Enterprise.Plan,
    Enterprise.Vendor,
    Notifications,
    Repo
  }

  alias WraftDoc.Account.Role
  alias WraftDoc.Enterprise.OrganisationRole
  alias WraftDocWeb.Worker.{EmailWorker, ScheduledWorker}

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
  def get_flow(flow_uuid, %{organisation_id: org_id}) do
    Repo.get_by(Flow, uuid: flow_uuid, organisation_id: org_id)
  end

  @doc """
  Get a state from its UUID and user's organisation.
  """
  @spec get_state(User.t(), Ecto.UUID.t()) :: State.t() | {:error, :invalid_id}
  def get_state(%User{organisation_id: org_id}, <<_::288>> = state_id) do
    query = from(s in State, where: s.id == ^state_id and s.organisation_id == ^org_id)

    case Repo.one(query) do
      %State{} = state -> state
      _ -> {:error, :invalid_id}
    end
  end

  def get_state(%User{organisation_id: _org_id}, _), do: {:error, :invalid_id}
  def get_state(_, <<_::288>>), do: {:error, :fake}

  @doc """
  Create a controlled flow flow.
  """
  @spec create_flow(User.t(), map) ::
          %Flow{creator: User.t()} | {:error, Ecto.Changeset.t()}

  def create_flow(%{organisation_id: org_id} = current_user, %{"controlled" => true} = params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:flows)
    |> Flow.controlled_changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, flow} ->
        Task.start_link(fn -> create_default_states(current_user, flow, true) end)
        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Create an uncontrolled flow flow.
  """

  def create_flow(%{organisation_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:flows)
    |> Flow.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, flow} ->
        Task.start_link(fn -> create_default_states(current_user, flow) end)
        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  List of all flows.
  """
  @spec flow_index(User.t(), map) :: map
  def flow_index(%User{organisation_id: org_id}, params) do
    query =
      from(f in Flow,
        where: f.organisation_id == ^org_id,
        order_by: [desc: f.id],
        preload: [:creator]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Show a flow.
  """
  @spec show_flow(binary, User.t()) :: Flow.t() | nil
  def show_flow(flow_uuid, user) do
    flow_uuid |> get_flow(user) |> Repo.preload([:creator, :states])
  end

  @doc """
  Update a controlled flow
  """
  def update_flow(flow, %User{id: id}, %{"controlled" => true} = params) do
    flow
    |> Flow.update_controlled_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:ok, flow} ->
        Repo.preload(flow, :creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Update a uncontrolled flow.
  """
  @spec update_flow(Flow.t(), User.t(), map) :: Flow.t() | {:error, Ecto.Changeset.t()}
  def update_flow(flow, %User{id: id}, params) do
    flow
    |> Flow.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
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
  @spec delete_flow(Flow.t(), User.t()) :: {:ok, Flow.t()} | {:error, Ecto.Changeset.t()}
  def delete_flow(flow, %User{id: id}) do
    flow
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :states,
      message:
        "Cannot delete the flow. Some States depend on this flow. Delete those states and then try again.!"
    )
    |> Spur.delete(%{actor: "#{id}", meta: flow})
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
  def create_state(%User{organisation_id: org_id} = current_user, flow, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:states, flow: flow)
    |> State.changeset(params)
    |> Spur.insert()
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
        where: f.uuid == ^flow_uuid and s.flow_id == f.id,
        order_by: [desc: s.id],
        preload: [:flow, :creator]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Update a state.
  """
  @spec update_state(State.t(), User.t(), map) ::
          %State{creator: User.t(), flow: Flow.t()} | {:error, Ecto.Changeset.t()}
  def update_state(state, %User{id: id}, params) do
    state
    |> State.changeset(params)
    |> Spur.update(%{actor: "#{id}"})
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
  @spec delete_state(State.t(), User.t()) :: {:ok, State.t()} | {:error, Ecto.Changeset.t()}
  def delete_state(state, %User{id: id}) do
    state
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the state. Some contents depend on this state. Update those states and then try again.!"
    )
    |> Spur.delete(%{actor: "#{id}", meta: state})
  end

  @doc """
  Get an organisation from its UUID.
  """

  @spec get_organisation(binary) :: Organisation.t() | nil
  def get_organisation(id) do
    Repo.get(Organisation, id)
  end

  @doc """
  Create an Organisation
  """

  @spec create_organisation(User.t(), map) :: {:ok, Organisation.t()}
  def create_organisation(%User{} = user, params) do
    user
    |> build_assoc(:organisation)
    |> Organisation.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, organisation} ->
        Task.start_link(fn -> create_membership(organisation) end)
        organisation

      {:error, _} = changeset ->
        changeset
    end
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
      :users,
      message:
        "Cannot delete the organisation. Some user depend on this organisation. Update those users and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Check the permission of the user wrt to the given organisation ID.
  """
  @spec check_permission(User.t(), binary) :: Organisation.t() | {:error, :no_permission}

  def check_permission(
        %{organisation: %{id: cuo_id} = organisation, role_names: role_names},
        o_id
      ) do
    cond do
      cuo_id === o_id ->
        organisation

      "super_admin" in role_names ->
        organisation

      true ->
        {:error, :no_permission}
    end
  end

  def check_permission(_, _), do: {:error, :no_permission}

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
  Send invitation email to given email.
  """

  @spec invite_team_member(User.t(), Organisation.t(), String.t()) ::
          {:ok, Oban.Job.t()} | {:error, any}
  def invite_team_member(%User{name: name}, %{name: org_name} = organisation, email) do
    token =
      Phoenix.Token.sign(WraftDocWeb.Endpoint, "organisation_invite", %{
        organisation: organisation,
        email: email
      })

    %{org_name: org_name, user_name: name, email: email, token: token}
    |> EmailWorker.new(queue: "mailer", tags: ["invite"])
    |> Oban.insert()
  end

  @doc """
  Send invitation email to given organisation.
  """

  def invite_team_member(%User{name: name}, %{name: org_name} = organisation, email, role)
      when is_binary(email)
      when is_binary(role) do
    token =
      Phoenix.Token.sign(WraftDocWeb.Endpoint, "organisation_invite", %{
        organisation: organisation,
        email: email,
        role: role
      })

    %{org_name: org_name, user_name: name, email: email, token: token}
    |> EmailWorker.new(queue: "mailer", tags: ["invite"])
    |> Oban.insert()
  end

  def invite_team_member(_, _, _, _), do: {:error, :no_data}

  @doc """
  Fetches the list of all members of current users organisation.
  """
  @spec members_index(User.t(), map) :: any
  def members_index(%User{organisation_id: organisation_id}, %{"name" => name} = params) do
    query =
      from(u in User,
        where: u.organisation_id == ^organisation_id,
        where: ilike(u.name, ^"%#{name}%"),
        preload: [:profile, :roles, :organisation]
      )

    Repo.paginate(query, params)
  end

  def members_index(%User{organisation_id: organisation_id}, params) do
    query =
      from(u in User,
        where: u.organisation_id == ^organisation_id,
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

  def list_organisations(%{"name" => name} = params) do
    query = from(o in Organisation, where: ilike(o.name, ^"%#{name}%"))
    Repo.paginate(query, params)
  end

  @doc """
  Function to list all organisation

  ## Parameters
  - `params` - A map of params to paginate list of organisation

  ## Examples
  organisations=list_organisations(%{"page"=>1})
  organisation.entries= [%Organisation{}]
  """
  @spec list_organisations(map) :: Scrivener.Page.t()
  def list_organisations(params) do
    Repo.paginate(Organisation, params)
  end

  @doc """
  Create approval system
  """
  @spec create_approval_system(User.t(), map) ::
          ApprovalSystem.t() | {:error, Ecto.Changeset.t()}
  def create_approval_system(
        %{organisation_id: org_id} = current_user,
        %{
          "instance_id" => instance_id,
          "pre_state_id" => pre_state_id,
          "post_state_id" => post_state_id,
          "approver_id" => approver_id
        }
      ) do
    with %Instance{} = instance <- Document.get_instance(instance_id, current_user),
         %State{} = pre_state <- get_state(current_user, pre_state_id),
         %State{} = post_state <- get_state(current_user, post_state_id),
         %User{} = approver <- Account.get_user_by_uuid(approver_id) do
      params = %{
        instance_id: instance.id,
        pre_state_id: pre_state.id,
        post_state_id: post_state.id,
        approver_id: approver.id,
        organisation_id: org_id
      }

      do_create_approval_system(current_user, params, approver)
    end
  end

  def create_approval_system(current_user, params) do
    do_create_approval_system(current_user, params)
  end

  defp do_create_approval_system(current_user, params, approver) do
    current_user
    |> build_assoc(:approval_systems)
    |> ApprovalSystem.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, approval_system} ->
        Task.start_link(fn ->
          Notifications.create_notification(
            approver,
            current_user.id,
            "assigned_as_approver",
            approval_system.id,
            ApprovalSystem
          )
        end)

        Repo.preload(approval_system, [
          :instance,
          :pre_state,
          :post_state,
          :approver,
          :organisation,
          :user
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  defp do_create_approval_system(current_user, params) do
    current_user
    |> build_assoc(:approval_systems)
    |> ApprovalSystem.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, approval_system} ->
        Repo.preload(approval_system, [
          :instance,
          :pre_state,
          :post_state,
          :approver,
          :organisation,
          :user
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Get approval system by uuid
  """

  @spec get_approval_system(Ecto.UUID.t(), User.t()) :: ApprovalSystem.t()
  def get_approval_system(id, %{organisation_id: org_id}) do
    ApprovalSystem
    |> Repo.get_by(id: id, organisation_id: org_id)
    |> Repo.preload([:instance, :pre_state, :post_state, :approver, :organisation, :user])
  end

  @doc """
  Update an uproval system
  """
  @spec update_approval_system(User.t(), ApprovalSystem.t(), map) ::
          ApprovalSystem.t() | {:error, Ecto.Changeset.t()}
  def update_approval_system(current_user, approval_system, %{
        "instance_id" => instance_id,
        "pre_state_id" => pre_state_id,
        "post_state_id" => post_state_id,
        "approver_id" => approver_id
      }) do
    with %Instance{} = instance <- Document.get_instance(instance_id, current_user),
         %State{} = pre_state <- get_state(current_user, pre_state_id),
         %State{} = post_state <- get_state(current_user, post_state_id),
         %User{} = approver <- Account.get_user_by_uuid(approver_id) do
      params = %{
        instance_id: instance.id,
        pre_state_id: pre_state.id,
        post_state_id: post_state.id,
        approver_id: approver.id
      }

      approval_system
      |> ApprovalSystem.changeset(params)
      |> Repo.update()
      |> case do
        {:error, _} = changeset ->
          changeset

        {:ok, approval_system} ->
          Task.start_link(fn ->
            Notifications.create_notification(
              approver.id,
              current_user.id,
              "assigned_as_approver",
              approval_system.uuid,
              ApprovalSystem
            )
          end)

          Repo.preload(approval_system, [
            :instance,
            :pre_state,
            :post_state,
            :approver,
            :organisation,
            :user
          ])
      end
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

  @doc """
  Delete an approval system
  """
  @spec delete_approval_system(ApprovalSystem.t()) :: ApprovalSystem.t()
  def delete_approval_system(%ApprovalSystem{} = approval_system) do
    Repo.delete(approval_system)
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
  Approve a content by approval system
  """

  @spec approve_content(User.t(), ApprovalSystem.t()) :: ApprovalSystem.t()
  def approve_content(
        current_user,
        %ApprovalSystem{
          instance: instance,
          post_state: post_state
        } = approval_system
      ) do
    Document.update_instance_state(current_user, instance, post_state)

    approval_system
    |> proceed_approval()
    |> Repo.preload(
      [
        :instance,
        :pre_state,
        :post_state,
        :approver,
        :user,
        :organisation
      ],
      force: true
    )
  end

  # Proceed approval make the status of approval system as approved

  @spec proceed_approval(ApprovalSystem.t()) :: ApprovalSystem.t()
  defp proceed_approval(approval_system) do
    params = %{approved: true, approved_log: NaiveDateTime.local_now()}

    approval_system
    |> ApprovalSystem.approve_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, approval_system} ->
        approval_system

      {:error, changeset} = changeset ->
        changeset
    end
  end

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
  def get_plan(<<_::288>> = p_uuid) do
    Repo.get_by(Plan, uuid: p_uuid)
  end

  def get_plan(_), do: nil

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
  defp create_membership(%Organisation{id: id}) do
    plan = Repo.get_by(Plan, name: @trial_plan_name)
    start_date = Timex.now()
    end_date = find_end_date(start_date, @trial_duration)
    params = %{start_date: start_date, end_date: end_date, plan_duration: @trial_duration}

    plan
    |> build_assoc(:memberships, organisation_id: id)
    |> Membership.changeset(params)
    |> Repo.insert!()
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
  def get_membership(<<_::288>> = m_uuid) do
    Repo.get_by(Membership, uuid: m_uuid)
  end

  def get_membership(_), do: nil

  @doc """
  Same as get_membership/2, but also uses user's organisation ID to get the membership.
  When the user is admin no need to check the user's organisation.
  """
  @spec get_membership(Ecto.UUID.t(), User.t()) :: Membership.t() | nil
  def get_membership(<<_::288>> = m_uuid, %{role_names: role_names, organisation_id: org_id}) do
    if Enum.member?(role_names, "super_admin") do
      get_membership(m_uuid)
    else
      Repo.get_by(Membership, uuid: m_uuid, organisation_id: org_id)
    end
  end

  # def get_membership(<<_::288>> = m_uuid, %User{role: %{name: "super_admin"}}) do
  #   get_membership(m_uuid)
  # end

  # def get_membership(<<_::288>> = m_uuid, %User{organisation_id: org_id}) do
  #   Repo.get_by(Membership, uuid: m_uuid, organisation_id: org_id)
  # end

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

  def get_organisation_membership(_), do: nil

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

  def update_membership(_, _, _, _), do: nil

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
    |> build_assoc(:payments, organisation_id: user.organisation_id)
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
  @spec get_payment(Ecto.UUID.t(), User.t()) :: Payment.t() | nil

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

  def get_payment(payment_id, %{organisation_id: org_id}) do
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
    |> build_assoc(:vendors, organisation_id: current_user.organisation.id)
    |> Vendor.changeset(params)
    |> Spur.insert()
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
  def get_vendor(%User{organisation_id: id}, uuid) do
    Repo.get_by(Vendor, uuid: uuid, organisation_id: id)
  end

  def get_vendor(_, _), do: nil
  @spec show_vendor(Ecto.UUID.t(), User.t()) :: Vendor.t()
  def show_vendor(uuid, user) do
    user |> get_vendor(uuid) |> Repo.preload([:creator, :organisation])
  end

  @doc """
  To update vendor details and attach logo file

  ## Parameters
  -`vendor`- a Vendor struct
  -`params`- a map contains vendor fields


  """

  def update_vendor(vendor, %User{id: id}, params) do
    vendor
    |> Vendor.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
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
  def vendor_index(%User{organisation_id: organisation_id}, params) do
    query = from(v in Vendor, where: v.organisation_id == ^organisation_id)
    Repo.paginate(query, params)
  end

  def vendor_index(_, _), do: nil

  @doc """
  Lists all pending approval systems to approve
  ## Parameters
  * user- User struct
  """
  @spec get_pending_approvals(User.t(), map()) :: Scrivener.Page.t()
  def get_pending_approvals(%User{id: id, organisation_id: org_id}, params) do
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

  def create_organisation_role(id, params) do
    organisation = get_organisation(id)

    Multi.new()
    |> Multi.insert(:role, Role.changeset(%Role{}, params))
    |> Multi.insert(:organisation_role, fn %{role: role} ->
      OrganisationRole.changeset(%OrganisationRole{}, %{
        organisation_id: organisation.id,
        role_id: role.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:error, _, changeset, _} ->
        {:error, changeset}

      {:ok, %{role: _role, organisation_role: organisation_role}} ->
        organisation_role
    end
  end

  def get_role(role \\ "admin")

  def get_role(role) when is_binary(role) do
    Repo.get_by(Role, name: role)
  end

  def get_organisation_id_and_role_id(org_id, r_id) do
    query =
      from(o in Organisation, where: o.uuid == ^org_id, join: r in Role, where: r.uuid == ^r_id)

    Repo.one(query)
  end

  def get_role_of_the_organisation(id, o_id) do
    query = from(r in Role, where: r.id == ^id, join: o in Organisation, where: o.id == ^o_id)
    Repo.one(query)
  end

  def delete_role_of_the_organisation(role) do
    role
    |> Repo.delete()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, role} ->
        role
    end
  end

  def get_organisation_id_roles(id) do
    query = from(o in Organisation, where: o.id == ^id)
    query |> Repo.one() |> Repo.preload(:roles)
  end
end
