defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto.Query
  import Ecto
  require Logger
  alias Ecto.Multi

  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Authorization.Permission
  alias WraftDoc.AuthTokens
  alias WraftDoc.Billing.PaddleApi
  alias WraftDoc.Billing.Subscription
  alias WraftDoc.Client.Razorpay
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Membership
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.Enterprise.StateUser
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Repo
  alias WraftDoc.TaskSupervisor
  alias WraftDoc.Workers.DefaultWorker
  alias WraftDoc.Workers.EmailWorker
  alias WraftDoc.Workers.ScheduledWorker

  @default_states [
    %{"state" => "Draft", "order" => 1, "approvers" => []},
    %{"state" => "Publish", "order" => 2, "approvers" => []}
  ]

  @default_controlled_states [
    %{"state" => "Draft", "order" => 1, "approvers" => []},
    %{"state" => "Review", "order" => 2, "approvers" => []},
    %{"state" => "Publish", "order" => 3, "approvers" => []}
  ]

  @is_self_hosted Application.compile_env(:wraft_doc, :deployement)[:is_self_hosted]

  @superadmin_role "superadmin"
  @editor_role "editor"

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
  @spec initial_state(Flow.t()) :: State.t() | nil
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
      %State{} = state -> Repo.preload(state, approvers: [:profile])
      _ -> {:error, :invalid_id}
    end
  end

  def get_state(%User{current_org_id: _org_id}, _), do: {:error, :invalid_id}
  def get_state(_, <<_::288>>), do: {:error, :fake}

  @doc """
    Get the final state for the given flow.
  """
  @spec get_final_state(Ecto.UUID.t()) :: State.t() | nil
  def get_final_state(<<_::288>> = flow_id) do
    State
    |> where(flow_id: ^flow_id)
    |> order_by(desc: :order)
    |> limit(1)
    |> Repo.one()
  end

  def get_final_state(_), do: nil

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
        flow = Repo.preload(flow, :creator)
        {:ok, flow}

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

        flow = Repo.preload(flow, :creator)
        {:ok, flow}

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
    |> Flow.align_order_changeset(modify_state_order(params))
    |> Repo.update()
    |> case do
      {:ok, flow} -> flow
      {:error, _} = changeset -> changeset
    end
  end

  # Private
  defp modify_state_order(%{"states" => states} = params) do
    states =
      states
      |> Enum.sort_by(& &1["order"], :asc)
      |> Enum.map(fn x -> Map.update!(x, "order", &(&1 + length(states))) end)

    Map.put(params, "states", states)
  end

  defp modify_state_order(params), do: params

  @doc """
  List of all flows.
  """
  @spec flow_index(User.t(), map) :: map
  def flow_index(%User{current_org_id: org_id}, params) do
    query =
      from(f in Flow,
        where: f.organisation_id == ^org_id,
        where: ^flow_index_filter_by_name(params),
        order_by: ^flow_index_sort(params),
        preload: [:creator]
      )

    Repo.paginate(query, params)
  end

  def flow_index(_, _), do: {:error, :fake}

  defp flow_index_filter_by_name(%{"name" => name} = _params),
    do: dynamic([f], ilike(f.name, ^"%#{name}%"))

  defp flow_index_filter_by_name(_), do: true

  defp flow_index_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([f], f.name)]

  defp flow_index_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([f], f.name)]

  defp flow_index_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([f], f.inserted_at)]

  defp flow_index_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([f], f.inserted_at)]

  defp flow_index_sort(%{"sort" => "updated_at"}), do: [asc: dynamic([f], f.updated_at)]

  defp flow_index_sort(%{"sort" => "updated_at_desc"}),
    do: [desc: dynamic([f], f.updated_at)]

  defp flow_index_sort(_), do: []

  @doc """
  Show a flow.
  """
  @spec show_flow(binary, User.t()) :: Flow.t() | nil
  def show_flow(flow_id, user) do
    with %Flow{} = flow <- get_flow(flow_id, user) do
      approvers_preloader = fn state_ids -> fetch_approvers_by_state_ids(state_ids) end

      Repo.preload(flow, [
        :creator,
        {:states, approvers: {approvers_preloader, :profile}},
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
    Enum.map(@default_controlled_states, fn x ->
      create_state(current_user, flow, put_in(x["approvers"], ["#{current_user.id}"]))
    end)
  end

  @doc """
  Create default states for an uncontrolled flow
  """
  def create_default_states(current_user, flow) do
    Enum.map(@default_states, fn x ->
      create_state(current_user, flow, put_in(x["approvers"], ["#{current_user.id}"]))
    end)
  end

  @doc """
  Create a state under a flow.
  """
  @spec create_state(User.t(), Flow.t(), map) :: State.t() | {:error, Ecto.Changeset.t()}
  def create_state(
        %User{current_org_id: org_id} = current_user,
        flow,
        %{"approvers" => approvers} = params
      ) do
    params = Map.merge(params, %{"organisation_id" => org_id, "flow_id" => flow.id})

    Multi.new()
    |> Multi.insert(
      :state,
      current_user
      |> build_assoc(:states)
      |> State.changeset(params)
    )
    |> Multi.run(:approvers, fn _repo, %{state: state} -> add_approvers(approvers, state) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{state: state}} -> Repo.preload(state, approvers: [:profile])
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  State index under a flow.
  """
  @spec state_index(binary()) :: map()
  def state_index(flow_uuid) do
    approvers_preloader = fn state_ids -> fetch_approvers_by_state_ids(state_ids) end

    State
    |> join(:inner, [s], f in Flow, on: f.id == ^flow_uuid and s.flow_id == f.id)
    |> order_by([s], desc: s.id)
    |> preload([s], [:flow, :creator, approvers: ^{approvers_preloader, :profile}])
    |> Repo.all()
  end

  # Private
  defp fetch_approvers_by_state_ids(state_ids) do
    User
    |> join(:inner, [u], su in StateUser, on: u.id == su.user_id and is_nil(su.content_id))
    |> where([_u, su], su.state_id in ^state_ids)
    |> select([u, su], {su.state_id, u})
    |> Repo.all()
  end

  @doc """
    Fetch flow state users for a document
  """
  @spec fetch_flow_state_users(binary(), binary()) :: [User.t()]
  def fetch_flow_state_users(<<_::288>> = state_id, <<_::288>> = document_id) do
    users_document_level =
      User
      |> join(:inner, [u], su in StateUser, on: u.id == su.user_id)
      |> where([_u, su], su.state_id == ^state_id and su.content_id == ^document_id)
      # User is removable at document level.
      |> select([u, _su], %{u | removable: true})

    users_content_type_level =
      User
      |> join(:inner, [u], su in StateUser, on: u.id == su.user_id)
      |> where([_u, su], su.state_id == ^state_id and is_nil(su.content_id))
      # User is not removable at document level.
      |> select([u, _su], %{u | removable: false})

    users_content_type_level
    |> union(^users_document_level)
    |> preload([_u], [:profile])
    |> Repo.all()
  end

  @doc """
    Add user to flow state at document level.
  """
  @spec add_user_to_state(Instance.t(), State.t(), map()) ::
          State.t() | {:error, Ecto.Changeset.t()}
  def add_user_to_state(
        %Instance{allowed_users: allowed_users} = instance,
        %State{} = state,
        %{"user_id" => user_id} = params
      ) do
    instance
    |> maybe_update_allowed_users(user_id, allowed_users)
    |> case do
      {:ok, _instance} ->
        %StateUser{}
        |> StateUser.add_document_level_user_changeset(params)
        |> Repo.insert()
        |> case do
          {:ok, _state_user} ->
            state
            |> Repo.reload()
            |> Repo.preload(approvers: [:profile])

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Private
  defp maybe_update_allowed_users(instance, user_id, allowed_users) do
    if user_id in allowed_users do
      {:ok, instance}
    else
      instance
      |> Instance.update_allowed_users_changeset(%{
        "allowed_users" => allowed_users ++ [user_id]
      })
      |> Repo.update()
    end
  end

  @doc """
    Remove user from a flow state at document level.
  """
  @spec remove_user_from_state(Instance.t(), State.t(), map()) ::
          State.t() | {:error, Ecto.Changeset.t()}
  def remove_user_from_state(
        %Instance{allowed_users: allowed_users} = instance,
        %State{} = state,
        %StateUser{content_id: <<_::288>> = _document_id, user_id: user_id} = state_user
      ) do
    state_user
    |> Repo.delete()
    |> case do
      {:ok, _state_user} ->
        state
        |> Repo.reload()
        |> Repo.preload(approvers: [:profile])
        |> maybe_remove_allowed_user(instance, user_id, allowed_users)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Private
  defp maybe_remove_allowed_user(state, instance, user_id, allowed_users) do
    if user_id in allowed_users do
      updated_users = List.delete(allowed_users, user_id)

      instance
      |> Instance.update_allowed_users_changeset(%{"allowed_users" => updated_users})
      |> Repo.update()
      |> case do
        {:ok, _instance} -> state
        {:error, _changeset} -> state
      end
    else
      state
    end
  end

  @doc """
  Update a state.
  """
  # TODO - Missing tests
  @spec update_state(State.t(), map()) ::
          %State{creator: User.t(), flow: Flow.t()} | {:error, Ecto.Changeset.t()}
  def update_state(
        state,
        %{
          "approvers" => %{
            "remove" => approvers_to_remove,
            "add" => approvers_to_add
          }
        } = params
      ) do
    Multi.new()
    |> Multi.update(
      :state,
      State.changeset(state, params)
    )
    |> Multi.run(:add_approvers, fn _repo, %{state: state} ->
      add_approvers(approvers_to_add, state)
    end)
    |> Multi.run(:remove_approvers, fn _repo, %{state: state} ->
      remove_approvers(approvers_to_remove, state.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{state: state}} -> Repo.preload(state, [:creator, :flow, approvers: [:profile]])
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def update_state(_state, _params), do: {:error, :invalid_data}

  defp add_approvers(approvers, state) do
    Enum.each(approvers, fn approver_id -> add_state_user(approver_id, state.id) end)

    {:ok, :ok}
  end

  @doc """
  Add user to state
  """
  @spec add_state_user(binary(), binary()) :: {:ok, StateUser.t()} | {:error, Ecto.Changeset.t()}
  def add_state_user(user_id, state_id) do
    Repo.insert(StateUser.changeset(%StateUser{}, %{state_id: state_id, user_id: user_id}))
  end

  @doc """
    Get user for a given state
  """
  @spec get_state_user(binary(), binary()) :: {:error, String.t()} | nil
  def get_state_user(user_id, state_id) do
    StateUser
    |> where([st], st.state_id == ^state_id and st.user_id == ^user_id and is_nil(st.content_id))
    |> Repo.one()
    |> case do
      nil -> nil
      _state_user -> {:error, "User already exists as an approver."}
    end
  end

  @doc """
  Get state user for given state along with document id.
  """
  @spec get_state_user(binary(), binary(), binary()) :: StateUser.t() | nil
  def get_state_user(user_id, state_id, document_id) do
    Repo.get_by(StateUser, state_id: state_id, user_id: user_id, content_id: document_id)
  end

  def remove_approvers(approvers_to_remove, state_id) do
    state_users = Repo.all(from(st in StateUser, where: st.state_id == ^state_id))

    Enum.each(approvers_to_remove, fn approver_id ->
      case state_users do
        # check if there are more than 2 approvers before deleting
        # we should have at least 1 approver
        list when length(list) >= 2 ->
          delete_approver(approver_id, state_id)

        _any ->
          Logger.info("Approver can't be removed")
      end
    end)

    {:ok, :ok}
  end

  def delete_approver(approver_id, state_id) do
    query =
      from(st in StateUser,
        where: st.user_id == ^approver_id and st.state_id == ^state_id and is_nil(st.content_id)
      )

    approver = Repo.one(query)

    if approver do
      Repo.delete(approver)
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
  def get_organisation(id), do: Repo.get(Organisation, id)

  @doc """
  Get an organisation with member count.
  """
  @spec get_organisation_with_member_count(binary) :: Organisation.t() | nil
  def get_organisation_with_member_count(organisation_id) do
    Organisation
    |> join(:left, [o], uo in assoc(o, :users_organisations), on: is_nil(uo.deleted_at))
    |> where([o], o.id == ^organisation_id)
    |> group_by([o], o.id)
    |> select_merge([o, uo], %{members_count: count(uo.id)})
    |> Repo.one()
  end

  @doc """
  Get personal organisation from user email
  """
  @spec get_personal_organisation_and_role(User.t()) ::
          %{organisation: Organisation.t(), user: User.t()}
  def get_personal_organisation_and_role(user) do
    organisation = Repo.get_by(Organisation, email: user.email, name: "Personal")

    user =
      user
      |> get_roles_by_organisation(organisation.id)
      |> Map.put(:current_org_id, organisation.id)

    %{organisation: organisation, user: user}
  end

  @doc """
  Gets all the roles of the user in the given organisation.
  """
  @spec get_roles_by_organisation(User.t(), Ecto.UUID.t()) :: User.t()
  def get_roles_by_organisation(user, organisation_id) do
    roles_preload_query = from(r in Role, where: r.organisation_id == ^organisation_id)
    Repo.preload(user, [roles: roles_preload_query], force: true)
  end

  @doc """
   Join organisation using an invite link
  """
  # TODO add test for existing user or deleted user joining again
  @spec join_org_by_invite(User.t(), binary()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def join_org_by_invite(%User{} = user, token) do
    Multi.new()
    |> Multi.run(:get_org, fn _, _ ->
      Account.get_organisation_and_role_from_token(%{"token" => token, "email" => user.email})
    end)
    |> Multi.insert(
      :users_organisations,
      fn %{get_org: %{organisation: organisation}} ->
        UserOrganisation.changeset(
          %UserOrganisation{},
          %{
            user_id: user.id,
            organisation_id: organisation.id
          }
        )
      end,
      on_conflict: [set: [deleted_at: nil]],
      conflict_target: [:organisation_id, :user_id]
    )
    |> Multi.run(:assign_role, fn _repo, %{get_org: %{role_ids: role_ids}} ->
      create_default_worker_job(%{user_id: user.id, roles: role_ids}, "assign_role")
    end)
    |> Multi.run(:delete_auth_token, fn _, _ -> AuthTokens.delete_auth_token(token) end)
    |> Repo.transaction()
    |> case do
      {:ok, %{get_org: %{organisation: organisation}}} ->
        {:ok, %{organisations: organisation}}

      {:error, :get_org, error, _} ->
        {:error, error}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Create an Organisation
  """
  @spec create_organisation(User.t(), map) :: Organisation.t()
  def create_organisation(%User{id: user_id} = user, params) do
    params = Map.merge(params, %{"owner_id" => user_id})

    Multi.new()
    |> Multi.insert(
      :organisation,
      user |> build_assoc(:owned_organisations) |> Organisation.changeset(params)
    )
    |> Multi.update(:organisation_logo, &Organisation.logo_changeset(&1.organisation, params))
    |> Multi.insert(:user_organisation, fn %{organisation: org} ->
      UserOrganisation.changeset(%UserOrganisation{}, %{user_id: user.id, organisation_id: org.id})
    end)
    |> then(fn multi ->
      if self_hosted?() do
        multi
      else
        Multi.run(multi, :subscription, fn _repo, %{organisation: organisation} ->
          create_free_subscription(organisation.id)
        end)
      end
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
    |> then(fn multi ->
      if self_hosted?() do
        multi
      else
        Multi.run(multi, :subscription, fn _repo, %{organisation: organisation} ->
          create_free_subscription(organisation.id)
        end)
      end
    end)
    |> Repo.transaction()
  end

  @doc """
  Update an Organisation
  """
  # TODO Add logo upload
  @spec update_organisation(Organisation.t(), map) :: {:ok, Organisation.t()}
  def update_organisation(organisation, params) do
    Multi.new()
    |> Multi.update(:organisation, Organisation.update_changeset(organisation, params))
    |> Multi.update(:organisation_logo, &Organisation.logo_changeset(&1.organisation, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{organisation_logo: organisation}} -> {:ok, organisation}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Deletes the organisation
  """
  def delete_organisation(%Organisation{name: "Personal"} = _organisation),
    do: {:error, :no_permission}

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
  Verify Delete Organisation Token
  """
  @spec verify_delete_token(map(), User.t()) :: :ok | {:error, :fake}
  def verify_delete_token(
        %{"token" => token} = _params,
        %User{current_org_id: org_id, email: email} = _user
      ) do
    case AuthTokens.check_token(token, :delete_code) do
      {:ok, %{email: ^email, organisation_id: ^org_id}} ->
        AuthTokens.delete_auth_token(token)

      _ ->
        {:error, :fake}
    end
  end

  def verify_delete_token(_, _), do: {:error, :fake}

  @doc """
  Generate Delete Organisation Token
  """
  @spec generate_delete_token_and_send_email(User.t(), Organisation.t()) :: {:ok, Oban.Job.t()}
  def generate_delete_token_and_send_email(
        %User{current_org_id: organisation_id, name: user_name, email: email} = user,
        %Organisation{name: organisation_name} = _organisation
      ) do
    token =
      WraftDoc.create_phx_token("delete_code", %{
        email: email,
        organisation_id: organisation_id
      })

    params = %{value: token, token_type: "delete_code"}

    AuthTokens.insert_auth_token!(user, params)

    %{email: email, token: token, user_name: user_name, organisation_name: organisation_name}
    |> EmailWorker.new(queue: "mailer", tags: ["organisation_delete_code"])
    |> Oban.insert()
  end

  @doc """
  Transfers the ownership of an organisation from the current owner to a new owner.
  """
  @spec transfer_ownership(Organisation.t(), Ecto.UUID.t()) :: Organisation.t()
  def transfer_ownership(
        %Organisation{owner_id: _owner_id} = organisation,
        new_owner_id
      ) do
    organisation
    |> Organisation.update_owner_changeset(%{owner_id: new_owner_id})
    |> Repo.update()
  end

  @doc """
  Check if a user with the given Email ID is a member of the given organisation.
  """
  @spec already_member(Ecto.UUID.t(), String.t()) :: :ok | {:error, :already_member}
  def already_member(<<_::288>> = _org_id, email) when is_nil(email), do: {:error, :no_data}

  def already_member(<<_::288>> = org_id, email) do
    query =
      from(user in User,
        where: user.email == ^email,
        join: user_org in UserOrganisation,
        on: user.id == user_org.user_id and user_org.organisation_id == ^org_id,
        where: is_nil(user_org.deleted_at)
      )

    case Repo.one(query) do
      %User{} -> {:error, :already_member}
      _ -> :ok
    end
  end

  @doc """
  Sends invitation email to the email with the role.
  """
  def invite_team_member(
        %User{name: name} = user,
        %{name: org_name} = organisation,
        email,
        role_ids
      )
      when is_binary(email) do
    token =
      WraftDoc.create_phx_token("organisation_invite", %{
        organisation_id: organisation.id,
        email: email,
        roles: role_ids
      })

    Task.start_link(fn ->
      AuthTokens.insert_auth_token!(user, %{value: token, token_type: "invite"})
    end)

    %{org_name: org_name, user_name: name, email: email, token: token}
    |> EmailWorker.new(queue: "mailer", tags: ["invite"])
    |> Oban.insert()
  end

  def invite_team_member(_, _, _, _), do: {:error, :no_data}

  @doc """
  Fetches the list of all members of current users organisation.
  """
  # TODO Add tests for filters
  @spec members_index(User.t(), map) :: any
  def members_index(%User{current_org_id: organisation_id}, params) do
    roles_preload_query = from(r in Role, where: r.organisation_id == ^organisation_id)

    user_organisation_query =
      from(uo in UserOrganisation, where: uo.organisation_id == ^organisation_id)

    User
    |> join(:inner, [u], uo in UserOrganisation, on: uo.user_id == u.id, as: :user_organisation)
    |> where([user_organisation: uo], uo.organisation_id == ^organisation_id)
    |> where(^members_filter_by_name(params))
    |> join(:left, [u], ur in UserRole, on: ur.user_id == u.id, as: :user_role)
    |> join(:left, [user_role: ur], r in Role,
      on: r.organisation_id == ^organisation_id and ur.role_id == r.id,
      as: :role
    )
    |> where(^members_filter_by_role(params))
    |> where([user_organisation: uo], is_nil(uo.deleted_at))
    |> group_by([u, user_organisation: uo], [u.id, uo.inserted_at])
    |> order_by(^members_index_sort(params))
    |> preload([
      :profile,
      [roles: ^roles_preload_query],
      [user_organisations: ^user_organisation_query]
    ])
    |> Repo.paginate(params)
  end

  defp members_filter_by_name(%{"name" => name} = _params),
    do: dynamic([u], ilike(u.name, ^"%#{name}%"))

  defp members_filter_by_name(_), do: true

  defp members_filter_by_role(%{"role" => role}) do
    dynamic([role: r], r.name == ^role)
  end

  defp members_filter_by_role(_), do: true

  defp members_index_sort(%{"sort" => "joined_at"}) do
    [asc: dynamic([user_organisation: uo], uo.inserted_at)]
  end

  defp members_index_sort(%{"sort" => "joined_at_desc"}) do
    [desc: dynamic([user_organisation: uo], uo.inserted_at)]
  end

  defp members_index_sort(%{"sort" => "name"}) do
    [asc: dynamic([u], u.name)]
  end

  defp members_index_sort(%{"sort" => "name_desc"}) do
    [desc: dynamic([u], u.name)]
  end

  defp members_index_sort(_), do: []

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
    query =
      from(org in Organisation,
        join: user_org in UserOrganisation,
        on: user_org.user_id == ^user.id and user_org.organisation_id == org.id,
        where: is_nil(user_org.deleted_at)
      )

    Repo.preload(user, organisations: query)
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
  @spec create_plan(map()) :: {:ok, Plan.t()} | {:error, Ecto.Changeset.t()}
  def create_plan(params) do
    Multi.new()
    |> Multi.insert(:plan, Plan.changeset(%Plan{}, params))
    |> Multi.run(:product, fn _, _ ->
      PaddleApi.create_product(params)
    end)
    |> Multi.run(:create_plan, fn _, %{product: %{"id" => product_id}} ->
      params
      |> Map.merge(%{"product_id" => product_id})
      |> PaddleApi.create_price()
    end)
    |> Multi.update(
      :update_plan,
      fn %{
           plan: plan,
           product: %{"id" => product_id}
         } = result ->
        params
        |> Map.merge(%{
          "product_id" => product_id,
          "plan_id" => get_in(result, [:create_plan, "id"])
        })
        |> then(&Plan.changeset(plan, &1))
      end
    )
    |> add_payment_link(params)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_plan: plan}} -> {:ok, plan}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp add_payment_link(multi, %{"type" => :enterprise}) do
    multi
    |> Multi.run(:payment_link, fn _, %{update_plan: plan} ->
      case PaddleApi.create_checkout_url(plan) do
        {:ok, url} ->
          {:ok, url}

        {:error, error} ->
          {:error, error}
      end
    end)
    |> Multi.update(:enterprise_plan, fn %{update_plan: plan, payment_link: payment_link} ->
      schedule_plan_expiry_job(plan)
      Plan.changeset(plan, %{payment_link: payment_link})
    end)
  end

  defp add_payment_link(multi, _), do: multi

  @doc """
  Get a plan from its UUID.
  """
  @spec get_plan(Ecto.UUID.t()) :: Plan.t() | {:error, :invalid_id, String.t()}

  def get_plan(<<_::288>> = plan_id) do
    case Repo.get(Plan, plan_id) do
      %Plan{} = plan -> Repo.preload(plan, :coupon)
      _ -> {:error, :invalid_id, "Plan"}
    end
  end

  def get_plan(_), do: {:error, :invalid_id, "Plan"}

  @doc """
  Get all plans.
  """
  @spec plan_index() :: [Plan.t()]
  def plan_index do
    Plan
    |> where([p], is_nil(p.custom))
    |> preload(:coupon)
    |> Repo.all()
  end

  @doc """
  Retrieve all active standard plans.
  """
  @spec active_plans() :: [Plan.t()]
  def active_plans do
    Plan
    |> where([p], is_nil(p.custom))
    |> where([p], p.is_active? == true)
    |> preload(:coupon)
    |> Repo.all()
  end

  @doc """
  Updates a plan.
  """
  @spec update_plan(Plan.t(), map()) :: {:ok, Plan.t()} | {:error, Ecto.Changeset.t()} | nil
  def update_plan(
        %Plan{
          product_id: product_id,
          plan_id: plan_id
        } = plan,
        params
      ) do
    Multi.new()
    |> Multi.run(:product, fn _, _ ->
      PaddleApi.update_product(product_id, params)
    end)
    |> Multi.run(:plan, fn _, _ ->
      PaddleApi.update_price(plan_id, params)
    end)
    |> Multi.update(
      :update_plan,
      fn _ ->
        Plan.changeset(plan, params)
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{update_plan: plan}} -> {:ok, plan}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def update_plan(_, _), do: nil

  @doc """
  Create free subscription for the given organisation.
  """
  @spec create_free_subscription(Ecto.UUID.t()) ::
          {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def create_free_subscription(organisation_id) do
    plan = Repo.get_by(Plan, name: "Free trial")

    params = %{
      plan_id: plan.id,
      organisation_id: organisation_id,
      currency: "USD",
      status: "active",
      next_bill_amount: "0"
    }

    %Subscription{}
    |> Subscription.free_subscription_changeset(params)
    |> Repo.insert()
  end

  defp schedule_plan_expiry_job(%Plan{id: id, custom: %{end_date: expiry_date}}) do
    %{plan_id: id}
    |> ScheduledWorker.new(scheduled_at: expiry_date)
    |> Oban.insert!()
  end

  # Create free trial membership for the given organisation.
  # @spec create_membership(Organisation.t()) :: Membership.t()
  # defp create_membership(%Organisation{id: id} = _organisation) do
  #   plan = Repo.get_by(Plan, name: @trial_plan_name)
  #   start_date = Timex.now()
  #   end_date = find_end_date(start_date, @trial_duration)
  #   params = %{start_date: start_date, end_date: end_date, plan_duration: @trial_duration}

  #   plan
  #   |> build_assoc(:memberships, organisation_id: id)
  #   |> Membership.changeset(params)
  #   |> Repo.insert!()
  #   |> case do
  #     %Membership{} = membership -> {:ok, membership}
  #     changeset -> {:error, changeset}
  #   end
  # end

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
  @spec update_membership(User.t(), Membership.t(), Plan.t(), map()) ::
          Membership.t() | {:ok, Payment.t()} | {:error, :wrong_amount} | nil
  def update_membership(
        %User{} = user,
        %Membership{} = membership,
        %Plan{} = plan,
        %{"status" => "failed"} = payment_details
      ) do
    params = create_payment_params(membership, plan, payment_details)
    user |> create_payment_changeset(params) |> Repo.insert()
  end

  def update_membership(
        %User{} = user,
        %Membership{} = membership,
        %Plan{} = plan,
        %{"amount" => amount} = payment_details
      ) do
    case get_duration_from_plan_and_amount(plan, amount) do
      duration when is_integer(duration) ->
        params = create_membership_and_payment_params(membership, plan, duration, payment_details)
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
          map()
        ) :: map
  defp create_membership_and_payment_params(membership, plan, duration, payment_details) do
    start_date = Timex.now()
    end_date = find_end_date(start_date, duration)

    membership
    |> create_payment_params(plan, payment_details)
    |> Map.merge(%{
      start_date: start_date,
      end_date: end_date,
      plan_duration: duration,
      plan_id: plan.id
    })
  end

  # Create payment params
  @spec create_payment_params(Membership.t(), Plan.t(), map()) :: map
  defp create_payment_params(
         membership,
         plan,
         %{"amount" => amount, "id" => r_id, "status" => status} = payment_details
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
      meta: payment_details,
      membership_id: membership.id
    }
  end

  # Gets the duration of selected plan based on the amount paid.
  @spec get_duration_from_plan_and_amount(Plan.t(), integer()) ::
          integer() | {:error, :wrong_amount}
  defp get_duration_from_plan_and_amount(%Plan{plan_amount: amount}, amount), do: 365
  defp get_duration_from_plan_and_amount(%Plan{plan_amount: amount}, amount), do: 30
  defp get_duration_from_plan_and_amount(_, _), do: {:error, :wrong_amount}

  # Gets the payment action comparing the old and new plans.
  @spec get_payment_action(Plan.t(), Plan.t()) :: integer
  defp get_payment_action(%Plan{id: id}, %Plan{id: id}) do
    Payment.actions()[:renew]
  end

  defp get_payment_action(%Plan{} = old_plan, %Plan{} = new_plan) do
    cond do
      old_plan.plan_amount > new_plan.plan_amount ->
        Payment.actions()[:downgrade]

      old_plan.plan_amount < new_plan.plan_amount ->
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
  @spec get_razorpay_data(binary) :: {:ok, map()} | {:error, map()}
  def get_razorpay_data(razorpay_id) do
    Razorpay.client().get_payment(razorpay_id)
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

  @doc """
  Inserts roles for an organisation and assigns the superadmin role to a user.

  ## Parameters
  - `organisation_id` - The ID of the organisation.
  - `user_id` - The ID of the user to be assigned the superadmin role.

  ## Returns
  - `:ok` if the roles were successfully inserted and the role was assigned.
  - `{:error, changeset}` if there was an error during the insertion or assignment.

  This function creates two roles (`superadmin` and `editor`) for the given organisation.
  It assigns the `superadmin` role to the specified user. If any step fails, it logs an error
  and returns the changeset causing the failure.

  ## Examples

      iex> insert_organisation_roles("org_123", "user_456")
      :ok

      iex> insert_organisation_roles("invalid_org", "user_456")
      {:error, %Ecto.Changeset{}}
  """
  @spec insert_organisation_roles(Ecto.UUID.t(), Ecto.UUID.t()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def insert_organisation_roles(organisation_id, user_id) do
    permissions = get_editor_permissions()

    Multi.new()
    |> Multi.insert(
      :superadmin_role,
      Role.changeset(%Role{}, %{
        name: @superadmin_role,
        organisation_id: organisation_id
      })
    )
    |> Multi.insert(
      :editor_role,
      Role.changeset(%Role{}, %{
        name: @editor_role,
        organisation_id: organisation_id,
        permissions: permissions
      })
    )
    |> Multi.run(:assign_role, fn _, %{superadmin_role: role} ->
      Account.create_user_role(user_id, role.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Organisation role insert failed", changeset: changeset)
        {:error, changeset}
    end
  end

  @doc """
  Retrieves the roles associated with a user's organisation

  ## Parameters
  * `user` - User struct
  * `params` - Map containing parameters for filtering and sorting

  ## Returns
  A list of Role structs
  """
  @spec roles_in_users_organisation(User.t(), map()) :: [Role.t()]
  def roles_in_users_organisation(%User{current_org_id: organisation_id}, params) do
    Role
    |> where([r], r.organisation_id == ^organisation_id)
    |> where(^roles_filter_by_name(params))
    |> order_by(^roles_sort(params))
    |> join(:left, [r], u in assoc(r, :users))
    |> select_merge([_r, u], %{user_count: count(u.id)})
    |> group_by([r], r.id)
    |> Repo.all()
  end

  defp roles_filter_by_name(%{"name" => name} = _params),
    do: dynamic([r], ilike(r.name, ^"%#{name}%"))

  defp roles_filter_by_name(_), do: true

  defp roles_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([r], r.name)]

  defp roles_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([r], r.name)]

  defp roles_sort(_), do: []

  @doc """
  Creates a default worker job
  """
  @spec create_default_worker_job(map(), binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def create_default_worker_job(args, tag) do
    args
    |> DefaultWorker.new(tags: [tag])
    |> Oban.insert()
  end

  @doc """
    Removes the given user from the organisation
  """
  @spec remove_user(UserOrganisation.t()) ::
          {:ok, UserOrganisation.t()} | {:error, Ecto.Changeset.t()}
  def remove_user(%UserOrganisation{} = user_organisation) do
    user_organisation
    |> UserOrganisation.delete_changeset(%{deleted_at: NaiveDateTime.local_now()})
    |> Repo.update()
  end

  @doc """
   Gets the UserOrganisation for given user ID and organisation ID
  """
  @spec get_user_organisation(User.t(), Ecto.UUID.t()) :: UserOrganisation.t() | nil
  def get_user_organisation(%User{current_org_id: org_id}, user_id) do
    UserOrganisation
    |> Repo.get_by(organisation_id: org_id, user_id: user_id)
    |> Repo.preload(:organisation)
  end

  @doc """
   Gets the permissions list for given user ID and organisation ID
  """
  # TODO Write tests
  @spec get_permissions(User.t()) :: map()
  def get_permissions(%User{current_org_id: org_id} = user) do
    roles_preload_query = from(r in Role, where: r.organisation_id == ^org_id)
    user = Repo.preload(user, roles: roles_preload_query)

    if Enum.member?(Enum.map(user.roles, & &1.name), "superadmin") do
      permission_names = Permission |> Repo.all() |> Enum.map(& &1.name)

      super_admin_role =
        user.roles
        |> Enum.filter(fn role -> role.name == "superadmin" end)
        |> List.first()
        |> Map.put(:permissions, permission_names)

      parse_permissions([super_admin_role])
    else
      parse_permissions(user.roles)
    end
  end

  # Private
  defp parse_permissions(roles) do
    roles
    |> Enum.map(fn role -> role.permissions end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.map(fn permission_name ->
      permission_name
      |> String.split(":")
      |> List.to_tuple()
    end)
    |> Enum.group_by(fn {resource, _} -> resource end, fn {_, action} -> action end)
  end

  defp get_editor_permissions do
    permissions_file_path =
      :wraft_doc |> :code.priv_dir() |> Path.join("repo/data/rbac/editor_permissions.csv")

    permissions_file_path
    |> File.stream!()
    |> CSV.decode()
    |> Enum.map(fn {:ok, [permission]} -> permission end)
  end

  @doc """
  Returns true if deployement mode is saas.
  """
  @spec self_hosted? :: boolean()
  def self_hosted?, do: @is_self_hosted
end
