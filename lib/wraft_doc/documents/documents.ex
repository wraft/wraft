defmodule WraftDoc.Documents do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.Client.Minio
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents.ContentCollaboration
  alias WraftDoc.Documents.Counter
  alias WraftDoc.Documents.Engine
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Instance.History
  alias WraftDoc.Documents.Instance.Version
  alias WraftDoc.Documents.InstanceApprovalSystem
  alias WraftDoc.Documents.InstanceTransitionLog
  alias WraftDoc.Documents.OrganisationField
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.StateUser
  alias WraftDoc.Fields.Field
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Themes
  alias WraftDoc.Utils.CSVHelper
  alias WraftDoc.Utils.ProsemirrorToMarkdown
  alias WraftDoc.Workers.BulkWorker
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Mailer
  alias WraftDocWeb.Mailer.Email

  @doc """
  List all engines.

  ## Example

    iex> engines_list(%{})
    list of available engines
  """
  @spec engines_list(map()) :: map()
  def engines_list(params) do
    Repo.paginate(Engine, params)
  end

  defp create_initial_version(%{id: author_id}, %Instance{id: document_id} = instance) do
    params = %{
      "version_number" => 1,
      "naration" => "Initial version",
      "raw" => instance.raw,
      "serialized" => instance.serialized,
      "author_id" => author_id,
      "content_id" => document_id
    }

    Logger.info("Creating initial version...")

    insert_initial_version(Map.merge(params, %{"type" => "save"}))
    insert_initial_version(Map.merge(params, %{"type" => "build"}))

    Logger.info("Initial version generated")
    {:ok, "ok"}
  end

  defp create_initial_version(_, _), do: {:error, :invalid}

  defp insert_initial_version(params) do
    %Version{}
    |> Version.changeset(params)
    |> Repo.insert!()
  end

  @doc """
  Same as create_instance/4, to create instance and its approval system
  """
  def create_instance(
        current_user,
        %{id: c_id, prefix: prefix, type: type} = content_type,
        _state,
        params
      ) do
    instance_id = create_instance_id(c_id, prefix)

    params =
      Map.merge(params, %{"instance_id" => instance_id, "allowed_users" => [current_user.id]})

    Multi.new()
    |> Multi.insert(
      :instance,
      content_type
      |> build_assoc(:instances, creator: current_user, document_type: type)
      |> Instance.changeset(params)
    )
    |> Multi.run(:counter_increment, fn _, _ -> create_or_update_counter(content_type) end)
    |> Multi.run(:instance_approval_system, fn _, %{instance: content} ->
      create_instance_approval_systems(content_type, content)
    end)
    |> Multi.run(:version, fn _, %{instance: content} ->
      create_initial_version(current_user, content)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{instance: content}} ->
        versions_preload_query =
          from(version in Version,
            where: version.content_id == ^content.id and version.type == :build,
            order_by: [desc: version.inserted_at],
            preload: [:author]
          )

        Repo.preload(content, [
          {:content_type, [layout: [:assets, :frame, :engine, :organisation]]},
          {:versions, versions_preload_query},
          :state,
          :vendor,
          :instance_approval_systems
        ])

      {:error, _, changeset, _} ->
        Logger.error("Creation of instance failed", changeset: changeset)
        {:error, changeset}
    end
  end

  # @spec create_instance(ContentType.t(), State.t(), map) ::
  #         %Instance{content_type: ContentType.t(), state: State.t()}
  #         | {:error, Ecto.Changeset.t()}
  def create_instance(%{id: c_id, prefix: prefix, type: type} = c_type, _state, params) do
    instance_id = create_instance_id(c_id, prefix)

    params =
      Map.merge(params, %{"instance_id" => instance_id, "allowed_users" => [params["creator_id"]]})

    c_type
    |> build_assoc(:instances, document_type: type)
    |> Instance.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, content} ->
        Task.start_link(fn -> create_or_update_counter(c_type) end)
        Task.start_link(fn -> create_instance_approval_systems(c_type, content) end)
        Repo.preload(content, [:content_type, :state])

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Create a new instance.
  """
  @spec create_instance(User.t(), ContentType.t(), map()) ::
          %Instance{content_type: ContentType.t(), state: State.t()}
          | {:error, Ecto.Changeset.t()}
  def create_instance(%User{} = current_user, %ContentType{type: type} = content_type, params) do
    instance_id = create_instance_id(content_type.id, content_type.prefix)

    params =
      Map.merge(params, %{
        "instance_id" => instance_id,
        "allowed_users" => [current_user.id]
      })

    Multi.new()
    |> Multi.insert(
      :instance,
      content_type
      |> build_assoc(:instances, creator: current_user, document_type: type)
      |> Instance.changeset(params)
    )
    |> Multi.run(:counter_increment, fn _, _ -> create_or_update_counter(content_type) end)
    |> Multi.run(:instance_approval_system, fn _, %{instance: content} ->
      create_instance_approval_systems(content_type, content)
    end)
    |> Multi.run(:version, fn _, %{instance: content} ->
      create_initial_version(current_user, content)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{instance: content}} ->
        Repo.preload(content, [
          :content_type,
          :state,
          :vendor,
          {:instance_approval_systems, :approver}
        ])

      {:error, _, changeset, _} ->
        Logger.error("Creation of instance failed", changeset: changeset)
        {:error, changeset}
    end
  end

  @doc """
    Update document meta data.
  """
  @spec update_instance(Instance.t(), map) ::
          {:ok, Instance.t()} | {:error, Ecto.Changeset.t()}
  def update_meta(%Instance{meta: %{"type" => type} = meta} = instance, params) do
    params
    |> put_in(["meta"], Map.merge(meta, params["meta"]))
    |> put_in(["meta", "type"], String.to_existing_atom(type))
    |> then(&Instance.meta_changeset(instance, &1))
    |> Repo.update()
  end

  @doc """
  Relate instace with approval system on creation
  ## Params
  * content_type - A content type struct
  * content - a Instance struct
  """
  @spec create_instance_approval_systems(ContentType.t(), Instance.t()) ::
          {:ok, :ok} | {:error, String.t()}
  def create_instance_approval_systems(content_type, content) do
    case Repo.preload(content_type, [{:flow, :approval_systems}]) do
      %ContentType{flow: %Flow{approval_systems: approval_systems}} ->
        {:ok,
         Enum.each(approval_systems, fn x ->
           create_instance_approval_system(%{
             instance_id: content.id,
             approval_system_id: x.id
           })
         end)}

      _ ->
        {:error, "flow not found"}
    end
  end

  @doc """
  Create an approval system from params

  """
  @spec create_instance_approval_system(map) ::
          {:ok, InstanceApprovalSystem.t()} | {:error, Ecto.Changeset.t()}
  def create_instance_approval_system(params) do
    %InstanceApprovalSystem{}
    |> InstanceApprovalSystem.changeset(params)
    |> Repo.insert()
  end

  # Initially moving state nil to intial state
  def approve_instance(
        %User{id: current_approver_id},
        %Instance{
          state: %State{id: current_state_id, approvers: approvers} = state,
          approval_status: false
        } = instance
      ) do
    if current_approver_id in Enum.map(approvers, & &1.id) do
      instance_state_transition_transaction(
        instance,
        %{
          state_id: next_state_id(state),
          approval_status: next_state_id(state) == current_state_id
        },
        %{
          review_status: :approved,
          reviewed_at: DateTime.utc_now(),
          from_state_id: current_state_id,
          reviewer_id: current_approver_id,
          instance_id: instance.id
        }
      )
    else
      {:error, :no_permission}
    end
  end

  def approve_instance(
        %User{id: current_approver_id},
        %Instance{
          allowed_users: [current_approver_id],
          state: nil,
          content_type: content_type,
          approval_status: false
        } = instance
      ) do
    flow = Repo.get(Flow, content_type.flow_id)
    initial_state = Enterprise.initial_state(flow)

    allowed_users =
      [current_approver_id]
      |> MapSet.new()
      |> MapSet.union(
        flow.id
        |> all_allowed_users()
        |> MapSet.new()
      )
      |> MapSet.to_list()

    instance_state_transition_transaction(
      instance,
      %{state_id: initial_state.id, allowed_users: allowed_users},
      %{
        review_status: :approved,
        reviewed_at: DateTime.utc_now(),
        reviewer_id: current_approver_id,
        instance_id: instance.id
      }
    )
  end

  def approve_instance(_, %Instance{state: nil}), do: {:error, :no_permission}

  def approve_instance(_, _), do: {:error, :cant_update}

  defp next_state_id(current_state) do
    query =
      from(s in State,
        where: s.flow_id == ^current_state.flow_id,
        where: s.order == ^(current_state.order + 1),
        select: s.id
      )

    Repo.one(query) || current_state.id
  end

  @doc """
  Next state of the document flow.
  """
  @spec next_state(State.t()) :: State.t() | nil
  def next_state(current_state) do
    State
    |> Repo.get(next_state_id(current_state))
    |> Repo.preload(:approvers)
  end

  def reject_instance(
        %User{id: current_approver_id},
        %Instance{
          state: %State{id: current_state_id, approvers: approvers} = state,
          approval_status: false
        } = instance
      ) do
    if current_approver_id in Enum.map(approvers, & &1.id) &&
         previous_state_id(state) != current_state_id do
      instance_state_transition_transaction(
        instance,
        %{state_id: previous_state_id(state)},
        %{
          review_status: :rejected,
          reviewed_at: DateTime.utc_now(),
          from_state_id: current_state_id,
          reviewer_id: current_approver_id,
          instance_id: instance.id
        }
      )
    else
      {:error, :no_permission}
    end
  end

  def reject_instance(_, _), do: {:error, :cant_update}

  defp instance_state_transition_transaction(
         instance,
         update_instance_params,
         instance_transition_log_params
       ) do
    Multi.new()
    |> Multi.update(
      :update_instance,
      Instance.update_state_changeset(instance, update_instance_params)
    )
    |> Multi.insert(:insert_transition_log, fn %{update_instance: %Instance{state_id: state_id}} ->
      InstanceTransitionLog.changeset(
        %InstanceTransitionLog{},
        Map.merge(
          instance_transition_log_params,
          %{to_state_id: state_id}
        )
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_instance: instance}} ->
        instance
        |> Repo.reload()
        |> Repo.preload([
          {:creator, :profile},
          {:content_type, :layout},
          {:versions, :author},
          {:state, :approvers}
        ])

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp previous_state_id(current_state) do
    query =
      from(s in State,
        where: s.flow_id == ^current_state.flow_id,
        where: s.order == ^(current_state.order - 1),
        select: s.id
      )

    Repo.one(query) || current_state.id
  end

  # defp allowed_users(state_id) do
  #   StateUser
  #   |> where([su], su.state_id == ^state_id)
  #   |> select([su], su.user_id)
  #   |> Repo.all()
  # end

  # Get all allowed users for a given flow.
  defp all_allowed_users(flow_id) do
    StateUser
    |> join(:inner, [su], s in State, on: su.state_id == s.id and s.flow_id == ^flow_id)
    |> select([su, s], su.user_id)
    |> Repo.all()
  end

  def update_instance_approval_system(instance, approval_system, params) do
    with %InstanceApprovalSystem{} = ias <-
           Repo.get_by(InstanceApprovalSystem,
             instance_id: instance.id,
             approval_system_id: approval_system.id
           ) do
      ias
      |> InstanceApprovalSystem.update_changeset(params)
      |> Repo.update()
    end
  end

  # Create Instance ID from the prefix of the content type
  @spec create_instance_id(integer, binary) :: binary
  defp create_instance_id(c_id, prefix) do
    instance_count =
      c_id
      |> get_counter_count_from_content_type_id
      |> add(1)
      |> to_string
      |> String.pad_leading(4, "0")

    concat_strings(prefix, instance_count)
  end

  # Create count of instances created for a content type from its ID
  @spec get_counter_count_from_content_type_id(integer) :: integer
  defp get_counter_count_from_content_type_id(c_type_id) do
    c_type_id
    |> get_counter_from_content_type_id
    |> case do
      nil ->
        0

      %Counter{count: count} ->
        count
    end
  end

  defp get_counter_from_content_type_id(c_type_id) do
    query = from(c in Counter, where: c.subject == ^"ContentType:#{c_type_id}")
    Repo.one(query)
  end

  @doc """
  Create or update the counter of a content type.integer()
  """
  # TODO - improve tests
  @spec create_or_update_counter(ContentType.t()) :: {:ok, Counter} | {:error, Ecto.Changeset.t()}
  def create_or_update_counter(%ContentType{id: id}) do
    id
    |> get_counter_from_content_type_id
    |> case do
      nil ->
        Counter.changeset(%Counter{}, %{subject: "ContentType:#{id}", count: 1})

      %Counter{count: count} = counter ->
        count = add(count, 1)
        Counter.changeset(counter, %{count: count})
    end
    |> Repo.insert_or_update()
  end

  # Add two integers
  @spec add(integer, integer) :: integer
  defp add(num1, num2) do
    num1 + num2
  end

  @doc """
  List all instances under an organisation.
  """
  @spec instance_index_of_an_organisation(User.t(), map()) :: map()
  def instance_index_of_an_organisation(
        %{current_org_id: org_id, role_names: role_names} = current_user,
        params
      ) do
    Instance
    |> join(:inner, [i], ct in ContentType,
      on: ct.organisation_id == ^org_id and i.content_type_id == ct.id,
      as: :content_type
    )
    |> superadmin_check("superadmin" in role_names, current_user)
    |> where(^instance_index_filter_by_instance_id(params))
    |> where(^instance_index_filter_by_content_type_name(params))
    |> where(^instance_index_filter_by_instance_title(params))
    |> instance_index_filter_by_state(params, org_id)
    |> where(^instance_index_filter_by_creator(params))
    |> order_by(^instance_index_sort(params))
    |> preload([
      :content_type,
      :state,
      :vendor,
      {:instance_approval_systems, :approver},
      {:creator, :profile}
    ])
    |> Repo.paginate(params)
  end

  def instance_index_of_an_organisation(_, _), do: {:error, :invalid_id}

  defp superadmin_check(query, true, current_user) do
    where(
      query,
      [i],
      (is_nil(i.state_id) and i.creator_id == ^current_user.id) or not is_nil(i.state_id)
    )
  end

  defp superadmin_check(query, false, current_user),
    do: where(query, [i], ^current_user.id in i.allowed_users)

  @doc """
  List all instances under a content types.
  """
  @spec instance_index(binary(), map()) :: map()
  def instance_index(<<_::288>> = c_type_id, params) do
    Instance
    |> join(:inner, [i], ct in ContentType, on: ct.id == ^c_type_id, as: :content_type)
    |> where([i, content_type: ct], i.content_type_id == ct.id)
    |> where(^instance_index_filter_by_instance_id(params))
    |> where(^instance_index_filter_by_creator(params))
    |> order_by(^instance_index_sort(params))
    |> preload([
      :content_type,
      :state,
      :vendor,
      {:instance_approval_systems, :approver},
      {:creator, :profile}
    ])
    |> Repo.paginate(params)
  end

  def instance_index(_, _), do: {:error, :invalid_id}

  defp instance_index_filter_by_instance_id(%{"instance_id" => instance_id} = _params),
    do: dynamic([i], ilike(i.instance_id, ^"%#{instance_id}%"))

  defp instance_index_filter_by_instance_id(_), do: true

  defp instance_index_filter_by_creator(%{"creator_id" => <<_::288>> = creator_id} = _params),
    do: dynamic([i], i.creator_id == ^creator_id)

  defp instance_index_filter_by_creator(_), do: true

  defp instance_index_filter_by_state(query, %{"state" => state} = _params, org_id) do
    query
    |> join(:inner, [i], s in State,
      on: i.state_id == s.id and s.organisation_id == ^org_id,
      as: :state
    )
    |> where([state: s], ilike(s.state, ^"%#{state}%"))
  end

  defp instance_index_filter_by_state(query, _, _), do: query

  defp instance_index_filter_by_instance_title(%{"document_instance_title" => title} = _params),
    do: dynamic([i], fragment("serialized ->> 'title' ilike ?", ^"%#{title}%"))

  defp instance_index_filter_by_instance_title(_), do: true

  defp instance_index_filter_by_content_type_name(%{"content_type_name" => name}) do
    dynamic([content_type: ct], ct.name == ^name)
  end

  defp instance_index_filter_by_content_type_name(_), do: true

  defp instance_index_sort(%{"sort" => "instance_id_desc"} = _params),
    do: [desc: dynamic([i], i.instance_id)]

  defp instance_index_sort(%{"sort" => "instance_id"} = _params),
    do: [asc: dynamic([i], i.instance_id)]

  defp instance_index_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([i], i.inserted_at)]

  defp instance_index_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([i], i.inserted_at)]

  defp instance_index_sort(_), do: []

  @doc """
  Search and list all by key
  """

  @spec instance_index(map(), map()) :: map()
  def instance_index(%{current_org_id: org_id}, key, params) do
    query =
      from(i in Instance,
        join: ct in ContentType,
        on: i.content_type_id == ct.id,
        where: ct.organisation_id == ^org_id,
        order_by: [desc: i.id],
        preload: [
          :content_type,
          :state,
          :vendor,
          {:instance_approval_systems, :approver},
          creator: [:profile]
        ]
      )

    key = String.downcase(key)

    query
    |> Repo.all()
    |> Stream.filter(fn
      %{serialized: %{"title" => title}} ->
        title
        |> String.downcase()
        |> String.contains?(key)

      _x ->
        nil
    end)
    |> Enum.filter(fn x -> !is_nil(x) end)
    |> Scrivener.paginate(params)
  end

  def instance_index(_, _, _), do: nil

  @doc """
  Get an instance from its UUID.
  """
  # TODO - improve tests
  @spec get_instance(binary(), User.t()) :: Instance.t() | nil
  def get_instance(<<_::288>> = document_id, %{current_org_id: nil}) do
    Repo.get(Instance, document_id)
  end

  def get_instance(<<_::288>> = id, %{current_org_id: org_id}) do
    query =
      from(i in Instance,
        where: i.id == ^id,
        join: c in ContentType,
        on: c.id == i.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %Instance{} = instance -> instance
      _ -> {:error, :invalid_id, "Instance"}
    end
  end

  def get_instance(_, %{current_org_id: _}), do: {:error, :invalid_id}
  def get_instance(_, _), do: {:error, :fake}

  @doc """
  Show an instance.
  """
  # TODO - improve tests
  @spec show_instance(binary(), User.t()) ::
          %Instance{creator: User.t(), content_type: ContentType.t(), state: State.t()} | nil
  def show_instance(instance_id, user) do
    # Preload the build versions of the instance
    versions_preload_query =
      from(version in Version,
        where: version.content_id == ^instance_id and version.type == :build,
        preload: [:author]
      )

    with %Instance{} = instance <- get_instance(instance_id, user) do
      instance
      |> Repo.preload([
        {:creator, :profile},
        {:content_type, [:layout, :organisation]},
        {:versions, versions_preload_query},
        {:state, :approvers},
        {:instance_approval_systems, :approver},
        state: [
          approval_system: [:post_state, :approver],
          rejection_system: [:pre_state, :approver]
        ]
      ])
      |> get_built_document()
    end
  end

  @doc """
  Get the build document of the given instance.
  """
  # TODO - improve tests
  @spec get_built_document(Instance.t()) :: Instance.t() | nil
  def get_built_document(
        %{
          id: id,
          instance_id: instance_id,
          content_type: %ContentType{organisation_id: org_id},
          versions: build_versions
        } = instance
      ) do
    query =
      from(h in History,
        where: h.exit_code == 0,
        where: h.content_id == ^id,
        order_by: [desc: h.inserted_at],
        limit: 1
      )

    query
    |> Repo.one()
    |> case do
      nil ->
        instance

      %History{} ->
        instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"

        file_path =
          Path.join(instance_dir_path, versioned_file_name(build_versions, instance_id, :current))

        doc_url = Minio.generate_url(file_path)

        Map.put(instance, :build, doc_url)
    end
  end

  @doc """
  Update an instance and creates updated version
  the instance is only available to edit if its editable field is true
  ## Parameters
  * `old_instance` - Instance struct before updation
  * `current_user` - User struct
  * `params` - Map contains attributes
  """
  # TODO - improve tests
  @spec update_instance(Instance.t(), map()) ::
          %Instance{content_type: ContentType.t(), state: State.t(), creator: Creator.t()}
          | {:error, Ecto.Changeset.t()}
  def update_instance(%Instance{editable: true} = old_instance, params) do
    old_instance
    |> Instance.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, instance} ->
        instance
        |> Repo.preload([
          {:creator, :profile},
          {:content_type, :layout},
          {:versions, :author},
          {:instance_approval_systems, :approver},
          state: [approval_system: [:post_state, :approver]]
        ])
        |> get_built_document()

      {:error, _} = changeset ->
        changeset
    end
  end

  def update_instance(%Instance{editable: false}, _params), do: {:error, :cant_update}

  def update_instance(_, _), do: {:error, :cant_update}

  # Create a new version with old data, when an instance is updated.
  # The previous data will be stored in the versions. Latest one will
  # be in the content.
  # A new version is added only if there is any difference in either the
  # raw or serialized fields of the instances.
  @spec create_version(User.t(), Instance.t(), map(), atom()) ::
          {:ok, Version.t()} | {:error, Ecto.Changeset.t()}
  def create_version(current_user, new_instance, params, type) do
    old_instance = get_last_version(new_instance, type)

    case instance_updated?(old_instance, new_instance) do
      true ->
        params = create_version_params(new_instance, params, type)

        current_user
        |> build_assoc(:instance_versions, content: new_instance)
        |> Version.changeset(params)
        |> Repo.insert()

      false ->
        nil
    end
  end

  defp get_last_version(%{id: id}, type) do
    query = from(v in Version, where: v.content_id == ^id and v.type == ^type)

    query
    |> last(:inserted_at)
    |> Repo.one()
  end

  defp get_last_version(_, _), do: nil
  # Create the params to create a new version.
  # @spec create_version_params(Instance.t(), map()) :: map
  defp create_version_params(%Instance{id: id} = instance, _params, type)
       when type in [:save, :build] do
    query =
      from(v in Version,
        where: v.content_id == ^id and v.type == ^type,
        order_by: [desc: v.inserted_at],
        limit: 1,
        select: v.version_number
      )

    incremented_version =
      query
      |> Repo.one()
      |> case do
        nil ->
          1

        version_number ->
          version_number + 1
      end

    # TODO - add naration
    # naration = params["naration"] || "Version-#{incremented_version / 10}"

    instance
    |> Map.from_struct()
    |> Map.merge(%{version_number: incremented_version, type: type})
  end

  defp create_version_params(_, params, _), do: params

  # Checks whether the raw and serialzed of old and new instances are same or not.
  # If they are both the same, returns false, else returns true
  # @spec instance_updated?(Instance.t(), Instance.t()) :: boolean
  defp instance_updated?(%{raw: o_raw, serialized: o_map}, %{raw: n_raw, serialized: n_map}) do
    !(o_raw === n_raw && o_map === n_map)
  end

  defp instance_updated?(_old_instance, _new_instance), do: true

  defp instance_updated?(new_instance) do
    new_instance
    |> get_last_version(:build)
    |> instance_updated?(new_instance)
  end

  @doc """
  Update instance's state if the flow IDs of both
  the new state and the instance's content type are same.
  """
  # TODO - impove tests
  @spec update_instance_state(Instance.t(), State.t()) ::
          Instance.t() | {:error, Ecto.Changeset.t()} | {:error, :wrong_flow}
  def update_instance_state(instance, %{id: state_id, flow_id: flow_id}) do
    case Repo.preload(instance, [:content_type]) do
      %{content_type: %{flow_id: ^flow_id}} ->
        instance_state_update(instance, state_id)

      _ ->
        :error
    end
  end

  @spec instance_state_update(Instance.t(), integer) ::
          Instance.t() | {:error, Ecto.Changeset.t()}
  defp instance_state_update(instance, state_id) do
    instance
    |> Instance.update_state_changeset(%{state_id: state_id})
    |> Repo.update()
    |> case do
      {:ok, instance} ->
        instance
        |> Repo.preload([
          {:creator, :profile},
          [content_type: [:flow, :layout]],
          {:state, :approval_system},
          :versions,
          :instance_approval_systems
        ])
        |> get_built_document()

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete an instance.
  """
  @spec delete_instance(Instance.t()) :: {:ok, Instance.t()} | {:error, any()}
  def delete_instance(instance), do: Repo.delete(instance)

  @doc """
  Delete uploaded documents of an instance.
  """
  @spec delete_uploaded_docs(User.t(), Instance.t()) :: {:ok, Instance.t()} | {:error, any()}
  def delete_uploaded_docs(
        %User{current_org_id: org_id} = _user,
        %Instance{instance_id: instance_id} = _instance
      ) do
    Minio.delete_files("organisations/#{org_id}/contents/#{instance_id}")
  end

  @doc """
  Get an engine from its UUID.
  """
  # TODO - improve tests
  @spec get_engine(binary) :: Engine.t() | nil
  def get_engine(<<_::288>> = engine_id) do
    case Repo.get(Engine, engine_id) do
      %Engine{} = engine -> engine
      _ -> {:error, :invalid_id, Engine}
    end
  end

  def get_engine(_), do: {:error, :invalid_id, Engine}

  @doc """
  Get an engine from its name.
  """
  @spec get_engine_by_name(String.t()) :: Engine.t() | nil
  def get_engine_by_name(engine_name) when is_binary(engine_name) do
    case Repo.get_by(Engine, name: engine_name) do
      %Engine{} = engine -> engine
      _ -> {:error, :invalid_id, Engine}
    end
  end

  def get_engine_by_name(_), do: {:error, :invalid_id, Engine}

  @doc """
  Build a PDF document.
  """
  # TODO  - Write Test
  # TODO - Dont need to pass layout as an argument, we can just preload it
  @spec build_doc(Instance.t(), Layout.t()) :: {any, integer}
  def build_doc(
        %Instance{instance_id: instance_id, content_type: content_type, versions: build_versions} =
          instance,
        %Layout{organisation_id: org_id} = layout
      ) do
    content_type = Repo.preload(content_type, [:fields, :theme])
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    base_content_dir = Path.join(File.cwd!(), instance_dir_path)
    File.mkdir_p(base_content_dir)
    File.mkdir_p(Path.join(File.cwd!(), "organisations/images/"))

    # Load all the assets corresponding with the given theme
    theme = Repo.preload(content_type.theme, [:assets])

    file_path = Assets.download_slug_file(layout)

    System.cmd("cp", ["-a", file_path, base_content_dir])

    # Generate QR code for the file
    task = Task.async(fn -> generate_qr(instance, base_content_dir) end)

    instance_updated? = instance_updated?(instance)
    # Move old builds to the history folder
    current_instance_file = versioned_file_name(build_versions, instance_id, :current)

    Task.start(fn ->
      move_old_builds(instance_dir_path, current_instance_file, instance_updated?)
    end)

    theme = Themes.get_theme_details(theme, base_content_dir)

    header =
      Enum.reduce(content_type.fields, "--- \n", fn x, acc ->
        find_header_values(x, instance.serialized, acc)
      end)

    content =
      prepare_markdown(
        instance,
        layout,
        header,
        base_content_dir,
        theme,
        task
      )

    File.write("#{base_content_dir}/content.md", content)
    File.write("#{base_content_dir}/fields.json", instance.serialized["fields"])

    pdf_file = Assets.pdf_file_path(instance, instance_dir_path, instance_updated?)

    pandoc_commands = prepare_pandoc_cmds(pdf_file, base_content_dir, layout)

    "pandoc"
    |> System.cmd(pandoc_commands, stderr_to_stdout: true)
    |> upload_file_and_delete_local_copy(base_content_dir, pdf_file)
  end

  def versioned_file_name(build_versions, instance_id, :current),
    do: instance_id <> "-v" <> to_string(length(build_versions)) <> ".pdf"

  def versioned_file_name(build_versions, instance_id, :next),
    do: instance_id <> "-v" <> to_string(length(build_versions) + 1) <> ".pdf"

  defp prepare_markdown(
         %{
           id: instance_id,
           doc_settings: document_settings,
           creator: %User{name: name, email: email}
         } = instance,
         %Layout{organisation: %Organisation{name: organisation_name}, slug: slug} = layout,
         header,
         mkdir,
         theme,
         task
       ) do
    header =
      Enum.reduce(layout.assets, header, fn asset, acc ->
        Assets.find_asset_header_values(asset, acc, layout, instance)
      end)

    qr_code = Task.await(task)
    page_title = instance.serialized["title"]

    header =
      header
      |> concat_strings("qrcode: #{qr_code} \n")
      |> concat_strings("path: #{mkdir}\n")
      |> concat_strings("title: #{page_title}\n")
      |> concat_strings("organisation_name: #{organisation_name}\n")
      |> concat_strings("author_name: #{name}\n")
      |> concat_strings("author_email: #{email}\n")
      |> concat_strings("id: #{instance_id}\n")
      |> concat_strings("mainfont: #{theme.font_name}\n")
      |> concat_strings("mainfont_base: #{theme.base_font_name}\n")
      |> concat_strings("mainfontoptions:\n")
      |> Themes.font_option_header(theme.font_options)
      |> concat_strings("body_color: \"#{theme.body_color}\"\n")
      |> concat_strings("primary_color: \"#{theme.primary_color}\"\n")
      |> concat_strings("secondary_color: \"#{theme.secondary_color}\"\n")
      |> concat_strings("typescale: #{theme.typescale}\n")
      |> document_option_header(document_settings, slug)
      |> concat_strings("--- \n")

    """
    #{header}
    #{instance.raw}
    """
  end

  defp document_option_header(
         header,
         %{
           table_of_content?: is_toc?,
           table_of_content_depth: toc_depth,
           qr?: is_qr?,
           default_cover?: is_default_cover?
         },
         slug
       ) do
    is_toc? = if "pletter" == slug, do: false, else: is_toc?

    header
    |> concat_strings("toc: #{is_toc?}\n")
    |> concat_strings("toc_depth: #{toc_depth}\n")
    |> concat_strings("qr: #{is_qr?}\n")
    |> concat_strings("default_cover: #{is_default_cover?}\n")
  end

  defp document_option_header(header, _, _), do: header

  defp prepare_pandoc_cmds(pdf_file, base_content_dir, %Layout{
         engine: %Engine{name: "Pandoc + Typst"}
       }) do
    [
      "-s",
      "#{base_content_dir}/content.md",
      "--template=#{base_content_dir}/default.typst",
      "--pdf-engine-opt=--root=/",
      "--pdf-engine-opt=--font-path=#{base_content_dir}/fonts",
      "--pdf-engine=typst"
    ] ++ get_pandoc_filter("s3_image_typst.lua") ++ ["-o", pdf_file]
  end

  defp prepare_pandoc_cmds(pdf_file, base_content_dir, _) do
    [
      "#{base_content_dir}/content.md",
      "--template=#{base_content_dir}/template.tex",
      "--pdf-engine=#{System.get_env("XELATEX_PATH")}"
    ] ++ get_pandoc_filter("s3_image.lua") ++ ["-o", pdf_file]
  end

  def get_pandoc_filter(filter_name) do
    filter = [File.cwd!(), "priv/pandoc_filters", filter_name]

    [
      "--lua-filter=#{Path.join(filter)}"
    ]
  end

  defp upload_file_and_delete_local_copy(
         {_, 0} = pandoc_response,
         file_path,
         pdf_file
       ) do
    case Minio.upload_file(pdf_file) do
      {:ok, _} ->
        File.rm_rf(file_path)
        File.rm_rf(Path.join(File.cwd!(), "organisations/images/"))
        pandoc_response

      _ ->
        File.rm(pdf_file)
        File.rm_rf(Path.join(File.cwd!(), "organisations/images/"))
        Logger.error("File upload failed")
        {"", 222}
    end
  end

  defp upload_file_and_delete_local_copy(pandoc_response, _, _), do: pandoc_response

  # Find the header values for the content.md file from the serialized data of an instance.
  @spec find_header_values(Field.t(), map, String.t()) :: String.t()
  defp find_header_values(%Field{name: key}, serialized, acc) do
    serialized
    |> Enum.find(fn {k, _} -> k == key end)
    |> case do
      nil ->
        acc

      {_, value} ->
        concat_strings(acc, "#{key}: #{value} \n")
    end
  end

  # Generate QR code with the UUID of the given Instance.
  @spec generate_qr(Instance.t(), String.t()) :: String.t()
  defp generate_qr(%Instance{id: id}, base_content_dir) do
    qr_code_png =
      id
      |> EQRCode.encode()
      |> EQRCode.png()

    destination = Path.join(base_content_dir, "/qr.png")
    File.write(destination, qr_code_png, [:binary])
    destination
  end

  # Concat two strings.
  @spec concat_strings(String.t(), String.t()) :: String.t()
  def concat_strings(string1, string2) do
    string1 <> string2
  end

  # Move old builds to the history folder
  @spec move_old_builds(String.t(), String.t(), boolean()) :: {:ok, non_neg_integer()}
  defp move_old_builds(instance_dir_path, file_name, true) do
    history_file = Path.join(instance_dir_path <> "/history", file_name)
    old_file = Path.join(instance_dir_path, file_name)
    Minio.copy_files(history_file, old_file)
    Minio.delete_file(old_file)
  end

  defp move_old_builds(_, _, false), do: nil

  @doc """
  Insert the build history of the given instance.
  """
  @spec add_build_history(User.t(), Instance.t(), map) :: History.t()
  def add_build_history(current_user, instance, params) do
    params = create_build_history_params(params)

    current_user
    |> build_assoc(:build_histories, content: instance)
    |> History.changeset(params)
    |> Repo.insert!()
  end

  @doc """
  Same as add_build_history/3, but creator will not be stored.
  """
  @spec add_build_history(Instance.t(), map) :: History.t()
  def add_build_history(instance, params) do
    params = create_build_history_params(params)

    instance
    |> build_assoc(:build_histories)
    |> History.changeset(params)
    |> Repo.insert!()
  end

  # Create params to insert build history
  # Build history Status will be "success" when exit code is 0
  @spec create_build_history_params(map) :: map
  defp create_build_history_params(%{exit_code: exit_code} = params) when exit_code == 0 do
    %{status: "success"} |> Map.merge(params) |> calculate_build_delay
  end

  # Build history Status will be "failed" when exit code is not 0
  defp create_build_history_params(params) do
    %{status: "failed"} |> Map.merge(params) |> calculate_build_delay
  end

  # Calculate the delay in the build process from the start and end time in the params.
  @spec calculate_build_delay(map) :: map
  defp calculate_build_delay(%{start_time: start_time, end_time: end_time} = params) do
    delay = Timex.diff(end_time, start_time, :millisecond)
    Map.merge(params, %{delay: delay})
  end

  @doc """
  Function to generate charts from diffrent endpoints as per input example api: https://quickchart.io/chart/create
  """
  # TODO - tests being failed with fake data test with real data,
  @spec generate_chart(map) :: map
  def generate_chart(%{"btype" => "gantt"}) do
    %{"url" => "gant_chart_url"}
  end

  def generate_chart(%{
        "dataset" => dataset,
        "api_route" => api_route,
        "endpoint" => "quick_chart"
      }) do
    %HTTPoison.Response{body: response_body} =
      HTTPoison.post!(api_route,
        body: Jason.encode!(dataset),
        headers: [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
      )

    Jason.decode!(response_body)
  end

  def generate_chart(%{"dataset" => dataset, "api_route" => api_route, "endpoint" => "blocks_api"}) do
    %HTTPoison.Response{body: response_body} =
      HTTPoison.post!(
        api_route,
        Jason.encode!(dataset),
        [{"Accept", "application./json"}, {"Content-Type", "application/json"}]
      )

    Jason.decode!(response_body)
  end

  # test results returning this function values
  def generate_chart(_params) do
    %{"status" => false, "error" => "invalid endpoint"}
  end

  @doc """
  Generate tex code for the chart
  """
  # TODO - improve tests, test with more data points
  @spec generate_tex_chart(map) :: <<_::64, _::_*8>>
  def generate_tex_chart(%{"dataset" => dataset, "btype" => "gantt"}) do
    generate_tex_gantt_chart(dataset)
  end

  def generate_tex_chart(%{"input" => input, "btype" => "gantt", "name" => name}) do
    generate_gnu_gantt_chart(input, name)
  end

  # current test giving this function output
  def generate_tex_chart(%{"dataset" => %{"data" => data}}) do
    "\\pie [rotate = 180 ]{#{tex_chart(data, "")}}"
  end

  defp tex_chart([%{"value" => value, "label" => label} | []], tex_chart) do
    "#{tex_chart}#{value}/#{label}"
  end

  defp tex_chart([%{"value" => value, "label" => label} | datas], tex_chart) do
    tex_chart = "#{tex_chart}#{value}/#{label}, "
    tex_chart(datas, tex_chart)
  end

  @doc """
  Generate latex of ganttchart
  """
  # TODO write test
  def generate_tex_gantt_chart(%{
        "caption" => caption,
        "title_list" => %{"start" => tl_start, "end" => tl_end},
        "data" => data
      }) do
    "\\documentclass[a4paper, 12pt,fleqn]{article}
      \\usepackage{pgfgantt}

        \\begin{document}
        \\begin{figure}
        \\centering
        \\begin{ganttchart}[%inline,bar inline label anchor=west,bar inline label node/.append style={anchor=west, text=white},bar/.append style={fill=cyan!90!black,},bar height=.8,]
        {#{tl_start}}{#{tl_end}}
        \\gantttitlelist{#{tl_start},...,#{tl_end}}{1}\\
        #{gant_bar(data, "", tl_end)}
        \\end{ganttchart}
        \\caption{#{caption}}
        \\end{figure}
        \\end{document}
        "
  end

  # Generate a Gantt chart form the given CSV file using Gnuplot CLI.
  defp generate_gnu_gantt_chart(%Plug.Upload{filename: filename, path: path}, title) do
    File.mkdir_p("temp/gantt_chart_input/")
    File.mkdir_p("temp/gantt_chart_output/")
    dest_path = "temp/gantt_chart_input/#{filename}"
    System.cmd("cp", [path, dest_path])

    dest_path = Path.expand(dest_path)
    out_name = Path.expand("temp/gantt_chart_output/gantt_#{title}.svg")

    script =
      File.read!("lib/priv/gantt_chart/gnuplot_gantt.plt")
      |> String.replace("//input//", dest_path)
      |> String.replace("//out_name//", out_name)
      |> String.replace("//title//", title)

    File.write("temp/gantt_script.plt", script)
    file_path = Path.expand("temp/gantt_script.plt")
    System.cmd("gnuplot", ["-p", file_path])
  end

  # Generate bar for gant chart
  defp gant_bar(
         [%{"label" => label, "start" => b_start, "end" => b_end, "bar" => bar} | data],
         g_bar,
         tl_end
       ) do
    gant_bar(data, "#{g_bar}\\ganttbar[inline=false]{#{label}}{#{b_start}}{#{b_end}}
     #{inline_gant_bar(bar, "", "", tl_end)}
    ", tl_end)
  end

  defp gant_bar([], g_bar, _tl_end) do
    g_bar
  end

  # Generate inline bar for gant chart
  defp inline_gant_bar(
         [%{"label" => label, "start" => b_start, "end" => b_end} | data],
         ig_bar,
         _b_end,
         tl_end
       ) do
    inline_gant_bar(data, "#{ig_bar}\\ganttbar{#{label}}{#{b_start}}{#{b_end}}", b_end, tl_end)
  end

  defp inline_gant_bar([], ig_bar, b_end, tl_end) do
    "#{ig_bar}
    \\ganttbar{}{#{b_end}}{#{tl_end}}\\"
  end

  # defp tex_chart([], tex_chart) do
  #   tex_chart
  # end

  @doc """
  Create a background job for Bulk build.
  """
  @spec insert_bulk_build_work(User.t(), binary(), binary(), binary(), map, Plug.Upload.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_bulk_build_work(
        %User{} = current_user,
        <<_::288>> = c_type_uuid,
        <<_::288>> = state_uuid,
        <<_::288>> = d_temp_uuid,
        mapping,
        %{
          filename: filename,
          path: path
        }
      ) do
    File.mkdir_p("temp/bulk_build_source/")
    dest_path = "temp/bulk_build_source/#{filename}"
    System.cmd("cp", [path, dest_path])

    create_bulk_job(%{
      user_uuid: current_user.id,
      c_type_uuid: c_type_uuid,
      state_uuid: state_uuid,
      d_temp_uuid: d_temp_uuid,
      mapping: mapping,
      file: dest_path
    })
  end

  def insert_bulk_build_work(_, _, _, _, _, _), do: nil

  @doc """
  Create a bulk job.
  """
  def create_bulk_job(args, scheduled_at \\ nil, tags \\ []) do
    args
    |> BulkWorker.new(tags: tags, scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  # def insert_block_template_bulk_import_work(_, _, %Plug.Upload{filename: _, path: _}),
  #   do: {:error, :fake}

  def insert_block_template_bulk_import_work(_, _, _), do: {:error, :invalid_data}

  @doc """
  Bulk build function.
  """
  # TODO - improve tests
  @spec bulk_doc_build(User.t(), ContentType.t(), State.t(), DataTemplate.t(), map, String.t()) ::
          list | {:error, :not_found}
  def bulk_doc_build(
        %User{} = current_user,
        %ContentType{} = c_type,
        %State{} = state,
        %DataTemplate{} = d_temp,
        mapping,
        path
      ) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = Map.keys(mapping)

    c_type = Repo.preload(c_type, [{:layout, :assets}])

    path
    |> CSVHelper.decode_csv(mapping_keys)
    |> Enum.map(fn x ->
      create_instance_params_for_bulk_build(x, d_temp, current_user, c_type, state, mapping)
    end)
    |> Stream.map(fn x -> bulk_build(current_user, x, c_type.layout) end)
    |> Enum.to_list()
  end

  def bulk_doc_build(_user, _c_type, _state, _d_temp, _mapping, _path) do
    {:error, :not_found}
  end

  @spec create_instance_params_for_bulk_build(
          map,
          DataTemplate.t(),
          User.t(),
          ContentType.t(),
          State.t(),
          map
        ) :: Instance.t()
  defp create_instance_params_for_bulk_build(
         serialized,
         %DataTemplate{} = d_temp,
         current_user,
         c_type,
         state,
         mapping
       ) do
    # The serialzed map's keys are changed to the values in the mapping. These
    # values are actually the fields of the content type.
    # This updated serialzed is then reduced to get the raw data
    # by replacing the variables in the data template.
    serialized = CSVHelper.update_keys(serialized, mapping)
    params = do_create_instance_params(serialized, d_temp)
    type = Instance.types()[:bulk_build]
    params = Map.merge(params, %{"type" => type, "state_id" => state.id})
    create_instance_for_bulk_build(current_user, c_type, params)
  end

  @doc """
  Generate params to create instance.
  """
  @spec do_create_instance_params(map, DataTemplate.t()) :: map
  def do_create_instance_params(field_with_values, %{
        title_template: title_temp,
        serialized: %{"data" => serialized_data}
      }) do
    updated_content = replace_content_holder(Jason.decode!(serialized_data), field_with_values)

    serialized =
      field_with_values
      |> Map.put("title", replace_content_title(field_with_values, title_temp))
      |> Map.put("serialized", Jason.encode!(updated_content))

    raw = ProsemirrorToMarkdown.convert(updated_content)

    %{"raw" => raw, "serialized" => serialized}
  end

  # Private
  defp replace_content_holder(
         %{"type" => "holder", "attrs" => %{"name" => name} = attrs} = content,
         data
       ) do
    case Map.get(data, name) do
      nil -> content
      named_value -> %{content | "attrs" => %{attrs | "named" => named_value}}
    end
  end

  defp replace_content_holder(%{"type" => _type, "content" => content} = node, data)
       when is_list(content) do
    updated_content = Enum.map(content, fn item -> replace_content_holder(item, data) end)
    %{node | "content" => updated_content}
  end

  defp replace_content_holder(other, _data), do: other

  defp replace_content_title(fields, title) do
    Enum.reduce(fields, title, fn {k, v}, acc ->
      WraftDoc.DocConversion.replace_content(k, v, acc)
    end)
  end

  # Create instance for bulk build. Uses the `create_instance/4` function
  # to create the instances. But the functions is run until the instance is created successfully.
  # Since we are iterating over list of params to create instances, there is a high chance of
  # unique ID of instances to repeat and hence for instance creation failures. This is why
  # we loop the fucntion until instance is successfully created.
  @spec create_instance_for_bulk_build(User.t(), ContentType.t(), map) :: Instance.t()
  defp create_instance_for_bulk_build(current_user, c_type, params) do
    instance = create_instance(current_user, c_type, params)

    case instance do
      %Instance{} = instance ->
        instance

      _ ->
        create_instance_for_bulk_build(current_user, c_type, params)
    end
  end

  @doc """
  Builds the doc using `build_doc/2`.
  Here we also records the build history using `add_build_history/3`.
  """
  # TODO - improve tests
  @spec bulk_build(User.t(), Instance.t(), Layout.t()) :: tuple
  def bulk_build(current_user, instance, layout) do
    start_time = Timex.now()
    {result, exit_code} = build_doc(instance, layout)
    end_time = Timex.now()

    add_build_history(current_user, instance, %{
      start_time: start_time,
      end_time: end_time,
      exit_code: exit_code
    })

    {result, exit_code}
  end

  @doc """
  Same as bulk_buil/3, but does not store the creator in build history.
  """
  @spec bulk_build(Instance.t(), Layout.t()) :: {Collectable.t(), non_neg_integer()}
  def bulk_build(instance, layout) do
    start_time = Timex.now()
    {result, exit_code} = build_doc(instance, layout)

    add_build_history(instance, %{
      start_time: start_time,
      end_time: Timex.now(),
      exit_code: exit_code
    })

    {result, exit_code}
  end

  @doc """
  Returns the list of organisation_field.

  ## Examples

      iex> list_organisation_field()
      [%OrganisationField{}, ...]

  """
  def list_organisation_fields(%{current_org_id: org_id}, params) do
    query =
      from(of in OrganisationField,
        where: of.organisation_id == ^org_id,
        order_by: [desc: of.id],
        preload: :field_type
      )

    Repo.paginate(query, params)
  end

  def list_organisation_fields(_, _), do: nil

  @doc """
  Gets a single organisation_field.

  Raises `Ecto.NoResultsError` if the Organisation field does not exist.

  ## Examples

      iex> get_organisation_field!(123)
      %OrganisationField{}

      iex> get_organisation_field!(456)
      ** (Ecto.NoResultsError)

  """
  def get_organisation_field(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(OrganisationField, id: id, organisation_id: org_id) do
      %OrganisationField{} = organisation_field -> organisation_field
      _ -> {:error, :invalid_id, "OrganisationField"}
    end
  end

  def organisation_field(_, %{organisation_field: _}),
    do: {:error, :invalid_id, "OrganisationField"}

  def organisation_field(_, _), do: {:error, :fake}
  @spec show_organisation_field(Ecto.UUID.t(), User.t()) :: OrganisationField.t()
  def show_organisation_field(id, user) do
    with %OrganisationField{} = organisation_field <- get_organisation_field(id, user) do
      Repo.preload(organisation_field, :field_type)
    end
  end

  @doc """
  Creates a organisation_field.

  ## Examples

      iex> create_organisation_field(%{field: value})
      {:ok, %OrganisationField{}}

      iex> create_organisation_field(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_organisation_field(%{current_org_id: org_id} = current_user, attrs) do
    attrs = Map.put(attrs, "organisation_id", org_id)

    current_user
    |> build_assoc(:organisation_fields)
    |> OrganisationField.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:error, _} = changeset -> changeset
      {:ok, organisation_field} -> Repo.preload(organisation_field, :field_type)
    end
  end

  def create_organisation_field(_, _, _), do: {:error, :fake}

  @doc """
  Updates a organisation_field.

  ## Examples

      iex> update_organisation_field(organisation_field, %{field: new_value})
      {:ok, %OrganisationField{}}

      iex> update_organisation_field(organisation_field, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_organisation_field(
        %{current_org_id: org_id},
        %OrganisationField{} = organisation_field,
        attrs
      ) do
    attrs = Map.put(attrs, "organisation_id", org_id)

    organisation_field
    |> OrganisationField.update_changeset(attrs)
    |> Repo.update()
    |> case do
      {:error, _} = changeset -> changeset
      {:ok, organisation_field} -> Repo.preload(organisation_field, :field_type)
    end
  end

  def update_organisation_field(_, _, _), do: {:error, :fake}

  @doc """
  Deletes a organisation_field.

  ## Examples

      iex> delete_organisation_field(organisation_field)
      {:ok, %OrganisationField{}}

      iex> delete_organisation_field(organisation_field)
      {:error, %Ecto.Changeset{}}

  """
  def delete_organisation_field(%OrganisationField{} = organisation_field) do
    Repo.delete(organisation_field)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking organisation_field changes.

  ## Examples

      iex> change_organisation_field(organisation_field)
      %Ecto.Changeset{source: %OrganisationField{}}

  """
  def change_organisation_field(%OrganisationField{} = organisation_field) do
    OrganisationField.changeset(organisation_field, %{})
  end

  @doc """
  To disable instance on edit
  ## Params
  * `instance` - Instance struct
  * `params` - map contains the value of editable
  """
  # TODO - Missing tests
  def lock_unlock_instance(%Instance{} = instance, params) do
    instance
    |> Instance.lock_modify_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, instance} ->
        Repo.preload(instance, [
          {:creator, :profile},
          {:content_type, :layout},
          {:versions, :author},
          {:instance_approval_systems, :approver},
          state: [approval_system: [:post_state, :approver]]
        ])
    end
  end

  def lock_unloack_instance(_, _, _), do: {:error, :not_sufficient}

  # @doc """
  # Search and list all by key
  # """

  # @spec instance_index(map(), map()) :: map
  # def instance_index(%{current_org_id: org_id}, key, params) do
  #   query =
  #     from(i in Instance,
  #       join: ct in ContentType,
  #       on: i.content_type_id == ct.id,
  #       where: ct.organisation_id == ^org_id,
  #       order_by: [desc: i.id],
  #       preload: [
  #         :content_type,
  #         :state,
  #         :vendor,
  #         {:instance_approval_systems, :approver},
  #         creator: [:profile]
  #       ]
  #     )

  #   key = String.downcase(key)

  #   query
  #   |> Repo.all()
  #   |> Stream.filter(fn
  #     %{serialized: %{"title" => title}} ->
  #       title
  #       |> String.downcase()
  #       |> String.contains?(key)

  #     _x ->
  #       nil
  #   end)
  #   |> Enum.filter(fn x -> !is_nil(x) end)
  #   |> Scrivener.paginate(params)
  # end

  # def instance_index(_, _, _), do: nil

  @doc """
  Function to list and paginate instance approval system under  an user
  """
  def instance_approval_system_index(<<_::288>> = user_id, params) do
    query =
      from(ias in InstanceApprovalSystem,
        join: as in ApprovalSystem,
        on: as.id == ias.approval_system_id,
        where: ias.flag == false,
        where: as.approver_id == ^user_id,
        preload: [:approval_system, instance: [:state, creator: [:profile]]]
      )

    Repo.paginate(query, params)
  end

  def instance_approval_system_index(%User{} = current_user, params) do
    query =
      from(ias in InstanceApprovalSystem,
        join: as in ApprovalSystem,
        on: as.id == ias.approval_system_id,
        where: ias.flag == false,
        where: as.approver_id == ^current_user.id,
        preload: [:approval_system, instance: [:state, creator: [:profile]]]
      )

    Repo.paginate(query, params)
  end

  def list_pending_approvals(%User{id: user_id, current_org_id: org_id} = _current_user, params) do
    next_state_query =
      from(s in State,
        where:
          s.flow_id == parent_as(^:state).flow_id and s.order == parent_as(^:state).order + 1,
        select: s.state
      )

    previous_state_query =
      from(s in State,
        where:
          s.flow_id == parent_as(^:state).flow_id and s.order == parent_as(^:state).order - 1,
        select: s.state
      )

    Instance
    |> where([i], i.approval_status == false)
    |> join(:inner, [i], s in State,
      on: s.id == i.state_id and s.organisation_id == ^org_id,
      as: :state
    )
    |> join(:inner, [i], su in StateUser,
      on: su.state_id == i.state_id and su.user_id == ^user_id,
      as: :state_users
    )
    |> select_merge([i], %{
      next_state: subquery(next_state_query),
      previous_state: subquery(previous_state_query)
    })
    |> preload([
      :state,
      {:creator, :profile}
    ])
    |> Repo.paginate(params)
  end

  @doc """
  Returns list of changes on a single version
  ## Parameters
  * `instance` - An instance struct
  * `version_uuid` - uuid of version
  """
  @spec version_changes(Instance.t(), <<_::288>>) :: map()
  def version_changes(instance, <<_::288>> = version_id) do
    case get_version(instance, version_id) do
      %Version{raw: current_raw} = version ->
        case get_previous_version(instance, version) do
          %Version{raw: previous_raw} ->
            list_changes(current_raw, previous_raw)

          _ ->
            %{ins: [], del: []}
        end

      _ ->
        {:error, :version_not_found}
    end
  end

  def version_changes(_, _), do: {:error, :invalid_id}

  defp list_changes(current_raw, previous_raw) do
    current_raw = String.split(current_raw, "\n")
    previous_raw = String.split(previous_raw, "\n")

    previous_raw
    |> List.myers_difference(current_raw)
    |> Enum.reduce(%{}, fn x, acc ->
      case x do
        {:ins, v} -> add_ins(v, acc)
        {:del, v} -> add_del(v, acc)
        {_, _} -> acc
      end
    end)
  end

  defp add_ins(v, %{ins: ins} = acc) do
    ins = ins |> List.insert_at(0, v) |> Enum.reverse()
    Map.put(acc, :ins, ins)
  end

  defp add_ins(v, acc) do
    ins = [v]
    Map.put(acc, :ins, ins)
  end

  defp add_del(v, %{del: del} = acc) do
    del = del |> List.insert_at(0, v) |> Enum.reverse()
    Map.put(acc, :del, del)
  end

  defp add_del(v, acc) do
    del = [v]
    Map.put(acc, :del, del)
  end

  defp get_version(%{id: instance_id}, <<_::288>> = version_id) do
    Repo.get_by(Version, content_id: instance_id, id: version_id)
  end

  defp get_version(_, _), do: nil

  defp get_previous_version(%{id: instance_id}, %{version_number: version_number, type: type}) do
    version_number = version_number - 1
    Repo.get_by(Version, version_number: version_number, content_id: instance_id, type: type)
  end

  defp get_previous_version(_, _), do: nil

  @doc """
  Retrieves dashboard statistics for the current organization.

  Returns a map containing the following keys:
  - `total_documents`: The total number of documents in the organization.
  - `daily_documents`: The number of documents created today.
  - `pending_approvals`: The number of documents awaiting approval.
  """
  @spec get_dashboard_stats(User.t()) :: map()
  def get_dashboard_stats(%{current_org_id: org_id}) do
    query = """
    SELECT
      total_documents,
      daily_documents,
      pending_approvals
    FROM
      dashboard_stats
    WHERE
      organisation_id = $1
    """

    # Convert string UUID to binary UUID
    org_id_binary = Ecto.UUID.dump!(org_id)

    case Ecto.Adapters.SQL.query(Repo, query, [org_id_binary]) do
      {:ok, %{rows: [[total, daily, pending]]}} ->
        %{
          total_documents: total,
          daily_documents: daily,
          pending_approvals: pending
        }

      _ ->
        %{total_documents: 0, daily_documents: 0, pending_approvals: 0}
    end
  end

  @doc """
  Send document as mail
  ## Parameters
  * instance - Instance struct
  * email - Email address
  * subject - Email subject
  * message - Email message
  * cc - Email cc
  """
  @spec send_document_email(Instance.t(), map()) :: {:ok, any()} | {:error, any()}
  def send_document_email(
        %{instance_id: instance_id, content_type: %{organisation_id: org_id}, versions: versions} =
          _instance,
        %{"email" => email, "subject" => subject, "message" => message} = params
      ) do
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    instance_file_name = versioned_file_name(versions, instance_id, :current)
    file_path = Path.join(instance_dir_path, instance_file_name)
    document_pdf_binary = Minio.download(file_path)

    email
    |> Email.document_instance_mail(
      subject,
      message,
      params["cc"],
      document_pdf_binary,
      instance_file_name
    )
    |> Mailer.deliver()
  end

  @doc """
  Share document
  """
  @spec send_email(Instance.t(), User.t(), String.t()) :: Oban.Job.t()
  def send_email(instance, user, token) do
    %{
      email: user.email,
      token: token,
      instance_id: instance.instance_id,
      document_id: instance.id
    }
    |> EmailWorker.new(queue: "mailer", tags: ["document_instance_share"])
    |> Oban.insert()
  end

  @doc """
  Add Content Collaborator
  """
  @spec add_content_collaborator(User.t(), Instance.t(), User.t(), map()) ::
          ContentCollaboration.t() | {:error, Ecto.Changeset.t()}
  def add_content_collaborator(
        %User{id: invited_by_id},
        %Instance{id: content_id, state_id: state_id},
        %User{id: user_id},
        %{
          "role" => role
        }
      ) do
    %ContentCollaboration{}
    |> ContentCollaboration.changeset(%{
      content_id: content_id,
      user_id: user_id,
      invited_by_id: invited_by_id,
      state_id: state_id,
      role: role
    })
    |> Repo.insert()
    |> case do
      {:ok, content_collaboration} ->
        Repo.preload(content_collaboration, [:user])

      changeset =
          {:error, %Ecto.Changeset{errors: [role: {"This email has already been invited.", _}]}} ->
        content_id
        |> get_content_collaboration(%User{id: user_id}, state_id)
        |> handle_invite_again(changeset)

      changeset = {:error, _} ->
        changeset
    end
  end

  def add_content_collaborator(_, _, _), do: {:error, "Invalid email"}

  # Invite again after revoked
  defp handle_invite_again(%ContentCollaboration{status: :revoked} = content_collaboration, _) do
    content_collaboration
    |> ContentCollaboration.status_update_changeset(%{status: "pending"})
    |> Repo.update()
    |> case do
      {:ok, content_collaboration} ->
        Repo.preload(content_collaboration, [:user])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp handle_invite_again(_, changeset), do: changeset

  @doc """
    Get Content Collaboration
  """
  def get_content_collaboration(document_id, %User{id: user_id}, state_id) do
    ContentCollaboration
    |> where(
      [cc],
      cc.content_id == ^document_id and cc.user_id == ^user_id and cc.state_id == ^state_id
    )
    |> Repo.one()
  end

  def get_content_collaboration(content_collaboration_id),
    do: Repo.get(ContentCollaboration, content_collaboration_id)

  @doc """
    Revoke Content Collaboration Access
  """
  @spec revoke_document_access(User.t(), ContentCollaboration.t()) ::
          ContentCollaboration.t() | {:error, Ecto.Changeset.t()}
  def revoke_document_access(
        %User{id: revoked_by_id},
        %ContentCollaboration{status: :accepted} = collaborator
      ) do
    collaborator
    |> ContentCollaboration.status_update_changeset(%{
      status: "revoked",
      revoked_by_id: revoked_by_id,
      revoked_at: DateTime.utc_now()
    })
    |> Repo.update()
    |> case do
      {:ok, collaborator} ->
        Repo.preload(collaborator, [:user])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def revoke_document_access(_, %ContentCollaboration{status: :pending}),
    do: {:error, "Collaborator not accepted"}

  def revoke_document_access(_, %ContentCollaboration{status: :revoked}),
    do: {:error, "Collaborator already revoked"}

  @doc """
  Accept Content Collaboration
  """
  @spec accept_document_access(ContentCollaboration.t()) ::
          {:ok, ContentCollaboration.t()}
  def accept_document_access(%{status: :pending} = content_collaboration) do
    content_collaboration
    |> ContentCollaboration.status_update_changeset(%{status: "accepted"})
    |> Repo.update()
  end

  def accept_document_access(%{status: :accepted} = content_collaboration) do
    {:ok, content_collaboration}
  end

  def accept_document_access(_), do: {:error, "Invalid status"}

  @doc """
    Check if user has access to a document
  """
  @spec has_access?(User.t(), Ecto.UUID.t()) :: boolean() | {:error, String.t()}
  def has_access?(%User{id: user_id}, document_id) do
    ContentCollaboration
    |> where(
      [cc],
      cc.content_id == ^document_id and cc.user_id == ^user_id and cc.status == :accepted
    )
    |> Repo.exists?()
    |> case do
      true -> true
      false -> {:error, "Collaborator does not have access to the document"}
    end
  end

  @spec has_access?(User.t(), Ecto.UUID.t(), atom()) :: boolean() | {:error, String.t()}
  def has_access?(%User{id: user_id}, document_id, :editor) do
    ContentCollaboration
    |> where(
      [cc],
      cc.content_id == ^document_id and cc.user_id == ^user_id and cc.status == :accepted and
        cc.role == :editor
    )
    |> Repo.exists?()
    |> case do
      true -> true
      false -> {:error, "Collaborator does not have access to the document"}
    end
  end

  # TODO removed because user can be guest to wraft or internal but not within organisation
  # def has_access?(%User{is_guest: false}, _), do: {:error, "Invalid user"}

  @doc """
    List collabortors for a document.
  """
  @spec list_collaborators(Instance.t()) :: [ContentCollaboration.t()] | []
  def list_collaborators(%Instance{id: <<_::288>> = content_id, state_id: <<_::288>> = state_id}) do
    ContentCollaboration
    |> where([cc], cc.content_id == ^content_id and cc.state_id == ^state_id)
    |> preload([cc], [:user])
    |> Repo.all()
  end

  def list_collaborators(_), do: []

  @doc """
    Update Content Collaborator Role
  """
  @spec update_collaborator_role(ContentCollaboration.t(), map()) ::
          ContentCollaboration.t() | {:error, Ecto.Changeset.t()}
  def update_collaborator_role(content_collaboration, %{"role" => _role} = params) do
    content_collaboration
    |> ContentCollaboration.role_update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, content_collaboration} ->
        Repo.preload(content_collaboration, [:user])

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
