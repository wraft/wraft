defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.{
    Account.Role,
    Account.User,
    Document.Asset,
    Document.Block,
    Document.BlockTemplate,
    Document.CollectionForm,
    Document.CollectionFormField,
    Document.Comment,
    Document.ContentType,
    Document.ContentTypeField,
    Document.ContentTypeRole,
    Document.Counter,
    Document.DataTemplate,
    Document.Engine,
    Document.FieldType,
    Document.Instance,
    Document.Instance.History,
    Document.Instance.Version,
    Document.InstanceApprovalSystem,
    Document.Layout,
    Document.LayoutAsset,
    Document.OrganisationField,
    Document.Pipeline,
    Document.Pipeline.Stage,
    Document.Pipeline.TriggerHistory,
    Document.Theme,
    Enterprise,
    Enterprise.ApprovalSystem,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Repo
  }

  alias WraftDocWeb.{AssetUploader, Worker.BulkWorker}

  @doc """
  Create a layout.
  """
  # TODO - improve tests
  @spec create_layout(User.t(), Engine.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def create_layout(%{organisation_id: org_id} = current_user, engine, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:layouts, engine: engine)
    |> Layout.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, layout} ->
        layout = layout_files_upload(layout, params)
        fetch_and_associcate_assets(layout, current_user, params)
        Repo.preload(layout, [:engine, :creator, :assets])

      changeset = {:error, _} ->
        changeset
    end
  end

  def create_layout(_, _, _), do: {:error, :fake}

  @doc """
  Upload layout slug file.
  """
  # TODO - write test
  @spec layout_files_upload(Layout.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def layout_files_upload(layout, %{"slug_file" => _} = params) do
    layout_update_files(layout, params)
  end

  def layout_files_upload(layout, %{"screenshot" => _} = params) do
    layout_update_files(layout, params)
  end

  def layout_files_upload(layout, _params) do
    Repo.preload(layout, [:engine, :creator])
  end

  # Update the layout on fileupload.
  @spec layout_update_files(Layout.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  defp layout_update_files(layout, params) do
    layout
    |> Layout.file_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, layout} ->
        layout

      {:error, _} = changeset ->
        changeset
    end
  end

  # Get all the assets from their UUIDs and associate them with the given layout.
  defp fetch_and_associcate_assets(layout, current_user, %{"assets" => assets}) do
    (assets || "")
    |> String.split(",")
    |> Stream.map(fn x -> get_asset(x, current_user) end)
    |> Stream.map(fn x -> associate_layout_and_asset(layout, current_user, x) end)
    |> Enum.to_list()
  end

  defp fetch_and_associcate_assets(_layout, _current_user, _params), do: nil

  # Associate the asset with the given layout, ie; insert a LayoutAsset entry.
  defp associate_layout_and_asset(_layout, _current_user, nil), do: nil

  defp associate_layout_and_asset(layout, current_user, asset) do
    layout
    |> build_assoc(:layout_assets, asset_id: asset.id, creator: current_user)
    |> LayoutAsset.changeset()
    |> Repo.insert()
  end

  @doc """
  Create a content type.
  """
  # TODO - improve tests
  @spec create_content_type(User.t(), Layout.t(), Flow.t(), map) ::
          ContentType.t() | {:error, Ecto.Changeset.t()}
  def create_content_type(%{organisation_id: org_id} = current_user, layout, flow, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:content_types, layout: layout, flow: flow)
    |> ContentType.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        fetch_and_associate_fields(content_type, params, current_user)
        Repo.preload(content_type, [:layout, :flow, {:fields, :field_type}])

      changeset = {:error, _} ->
        changeset
    end
  end

  @spec fetch_and_associate_fields(ContentType.t(), map, User.t()) :: list
  # Iterate throught the list of field types and associate with the content type
  defp fetch_and_associate_fields(content_type, %{"fields" => fields}, user) do
    fields
    |> Stream.map(fn x -> associate_c_type_and_fields(content_type, x, user) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_fields(_content_type, _params, _user), do: nil

  @spec associate_c_type_and_fields(ContentType.t(), map, User.t()) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()} | nil
  # Fetch and associate field types with the content type
  defp associate_c_type_and_fields(
         c_type,
         %{"key" => key, "field_type_id" => field_type_id},
         user
       ) do
    field_type_id
    |> get_field_type(user)
    |> case do
      %FieldType{} = field_type ->
        field_type
        |> build_assoc(:fields, content_type: c_type)
        |> ContentTypeField.changeset(%{name: key})
        |> Repo.insert()

      nil ->
        nil
    end
  end

  defp associate_c_type_and_fields(_c_type, _field, _user), do: nil

  @doc """
  List all engines.
  """
  # TODO - write tests
  @spec engines_list(map) :: map
  def engines_list(params) do
    Repo.paginate(Engine, params)
  end

  @doc """
  List all layouts.
  """
  # TODO - improve tests
  @spec layout_index(User.t(), map) :: map
  def layout_index(%{organisation_id: org_id}, params) do
    query =
      from(l in Layout,
        where: l.organisation_id == ^org_id,
        order_by: [desc: l.inserted_at],
        preload: [:engine, :assets]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Show a layout.
  """
  @spec show_layout(binary, User.t()) :: %Layout{engine: Engine.t(), creator: User.t()}
  def show_layout(id, user) do
    with %Layout{} = layout <-
           get_layout(id, user) do
      Repo.preload(layout, [:engine, :creator, :assets])
    end
  end

  @doc """
  Get a layout from its UUID.
  """
  @spec get_layout(binary, User.t()) :: Layout.t()
  def get_layout(<<_::288>> = id, %{organisation_id: org_id}) do
    case Repo.get_by(Layout, id: id, organisation_id: org_id) do
      %Layout{} = layout ->
        layout

      _ ->
        {:error, :invalid_id, "Layout"}
    end
  end

  def get_layout(_, %{organisation_id: _}), do: {:error, :invalid_id, "Layout"}
  def get_layout(_, _), do: {:error, :fake}

  @doc """
  Get a layout asset from its layout's and asset's UUIDs.
  """
  # TODO - improve tests
  @spec get_layout_asset(binary, binary) :: LayoutAsset.t()
  def get_layout_asset(<<_::288>> = l_id, <<_::288>> = a_id) do
    query =
      from(la in LayoutAsset,
        join: l in Layout,
        where: l.id == ^l_id,
        join: a in Asset,
        where: a.id == ^a_id,
        where: la.layout_id == l.id and la.asset_id == a.id
      )

    case Repo.one(query) do
      %LayoutAsset{} = layout_asset -> layout_asset
      _ -> {:error, :invalid_id}
    end
  end

  def get_layout_asset(<<_::288>>, _), do: {:error, :invalid_id, Layout}
  def get_layout_asset(_, <<_::288>>), do: {:error, :invalid_id, Asset}

  @doc """
  Update a layout.
  """
  # TODO - improve tests
  @spec update_layout(Layout.t(), User.t(), map) :: %Layout{engine: Engine.t(), creator: User.t()}

  def update_layout(layout, %{id: user_id} = current_user, params) do
    layout
    |> Layout.update_changeset(params)
    |> Spur.update(%{actor: user_id})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, layout} ->
        fetch_and_associcate_assets(layout, current_user, params)
        Repo.preload(layout, [:engine, :creator, :assets])
    end
  end

  @doc """
  Delete a layout.
  """
  # TODO - improve tests
  @spec delete_layout(Layout.t(), User.t()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def delete_layout(layout, %User{id: id}) do
    layout
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :content_types,
      message:
        "Cannot delete the layout. Some Content types depend on this layout. Update those content types and then try again.!"
    )
    |> Spur.delete(%{actor: "#{id}", meta: layout})
  end

  @doc """
  Delete a layout asset.
  """
  # TODO - improve tests
  @spec delete_layout_asset(LayoutAsset.t(), User.t()) ::
          {:ok, LayoutAsset.t()} | {:error, Ecto.Changeset.t()}
  def delete_layout_asset(layout_asset, %User{id: id}) do
    %{asset: asset} = Repo.preload(layout_asset, [:asset])
    Spur.delete(layout_asset, %{actor: "#{id}", meta: asset})
  end

  @doc """
  List all content types.
  """
  # TODO - improve tests
  @spec content_type_index(User.t(), map) :: map
  def content_type_index(%{organisation_id: org_id}, params) do
    query =
      from(ct in ContentType,
        where: ct.organisation_id == ^org_id,
        order_by: [desc: ct.id],
        preload: [:layout, :flow, {:fields, :field_type}]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Show a content type.
  """
  # TODO - improve tests
  @spec show_content_type(User.t(), Ecto.UUID.t()) ::
          %ContentType{layout: Layout.t(), creator: User.t()} | nil
  def show_content_type(user, id) do
    with %ContentType{} = content_type <- get_content_type(user, id) do
      Repo.preload(content_type, [:layout, :creator, [{:fields, :field_type}, {:flow, :states}]])
    end
  end

  @doc """
  Get a content type from its UUID and user's organisation ID.
  """
  # TODO - improve tests
  @spec get_content_type(User.t(), Ecto.UUID.t()) :: ContentType.t() | nil
  def get_content_type(%User{organisation_id: org_id}, <<_::288>> = id) do
    query = Repo.get_by(ContentType, id: id, organisation_id: org_id)

    case query do
      %ContentType{} = content_type -> content_type
      _ -> {:error, :invalid_id, "ContentType"}
    end
  end

  def get_content_type(%User{organisation_id: _org_id}, _),
    do: {:error, :invalid_id, "ContentType"}

  def get_content_type(_, _), do: {:error, :fake}

  @doc """
  Get a content type from its ID. Also fetches all its related datas.
  """
  # TODO - write tests
  @spec get_content_type_from_id(integer()) :: %ContentType{layout: %Layout{}, creator: %User{}}
  def get_content_type_from_id(id) do
    ContentType
    |> Repo.get(id)
    |> Repo.preload([:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
  end

  @doc """
  Get a content type field from its UUID.
  """
  # TODO - write tests
  @spec get_content_type_field(binary, User.t()) :: ContentTypeField.t()
  def get_content_type_field(<<_::288>> = id, %{organisation_id: org_id}) do
    query =
      from(cf in ContentTypeField,
        where: cf.id == ^id,
        join: c in ContentType,
        where: c.id == cf.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %ContentTypeField{} = content_type_field -> content_type_field
      _ -> {:error, :invalid_id, "ContentTypeField"}
    end
  end

  def get_content_type_field(<<_::288>>, _), do: {:error, :invalid_id, "ContentTypeField"}
  def get_content_type_field(_, %{organisation_id: _}), do: {:error, :fake}

  @doc """
  Update a content type.
  """
  # TODO - write tests
  @spec update_content_type(ContentType.t(), User.t(), map) ::
          %ContentType{
            layout: Layout.t(),
            creator: User.t()
          }
          | {:error, Ecto.Changeset.t()}
  def update_content_type(
        content_type,
        user,
        %{"layout_uuid" => layout_uuid, "flow_uuid" => f_uuid} = params
      ) do
    %Layout{id: id} = get_layout(layout_uuid, user)
    %Flow{id: f_id} = Enterprise.get_flow(f_uuid, user)
    {_, params} = Map.pop(params, "layout_uuid")
    {_, params} = Map.pop(params, "flow_uuid")
    params = Map.merge(params, %{"layout_id" => id, "flow_id" => f_id})
    update_content_type(content_type, user, params)
  end

  def update_content_type(content_type, %User{id: id} = user, params) do
    content_type
    |> ContentType.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type} ->
        fetch_and_associate_fields(content_type, params, user)

        Repo.preload(content_type, [:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
    end
  end

  @doc """
  Delete a content type.
  """
  # TODO - write tests
  @spec delete_content_type(ContentType.t(), User.t()) ::
          {:ok, ContentType.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type(content_type, %User{id: id}) do
    content_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the content type. There are many contents under this content type. Delete those contents and try again.!"
    )
    |> Spur.delete(%{actor: "#{id}", meta: content_type})
  end

  @doc """
  Delete a content type field.
  """
  # TODO - improve tests
  @spec delete_content_type_field(ContentTypeField.t(), User.t()) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type_field(content_type_field, %User{id: id}) do
    Spur.delete(content_type_field, %{actor: id, meta: content_type_field})
  end

  def delete_content_type_field(_, _), do: {:error, :fake}

  defp create_initial_version(%{id: author_id}, instance) do
    params = %{
      "version_number" => 1,
      "naration" => "Initial version",
      "raw" => instance.raw,
      "serialized" => instance.serialized,
      "author_id" => author_id
    }

    IO.puts("Creating initial version...")

    %Version{}
    |> Version.changeset(params)
    |> Repo.insert!()

    IO.puts("Initial version generated")
  end

  defp create_initial_version(_, _), do: nil

  @doc """
  Same as create_instance/4, to create instance and its approval system
  """

  # TODO write tests
  def create_instance(current_user, %{id: c_id, prefix: prefix} = c_type, state, params) do
    instance_id = create_instance_id(c_id, prefix)
    params = Map.merge(params, %{"instance_id" => instance_id})

    c_type
    |> build_assoc(:instances, creator: current_user, state_id: state.id)
    |> Instance.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, content} ->
        Task.start_link(fn -> create_or_update_counter(c_type) end)

        create_instance_approval_systems(c_type, content)

        Repo.preload(content, [:content_type, :state, :vendor, :instance_approval_systems])

      changeset = {:error, _} ->
        changeset
    end
  end

  @spec create_instance(ContentType.t(), State.t(), map) ::
          %Instance{content_type: ContentType.t(), state: State.t()}
          | {:error, Ecto.Changeset.t()}
  def create_instance(%{id: c_id, prefix: prefix} = c_type, state, params) do
    instance_id = create_instance_id(c_id, prefix)
    params = Map.merge(params, %{"instance_id" => instance_id})

    c_type
    |> build_assoc(:instances, state_id: state.id)
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
  # TODO - improve tests
  @spec create_instance(User.t(), ContentType.t(), map) ::
          %Instance{content_type: ContentType.t(), state: State.t()}
          | {:error, Ecto.Changeset.t()}
  def create_instance(
        %User{} = current_user,
        %{id: c_id, prefix: prefix, flow: flow} = c_type,
        params
      ) do
    instance_id = create_instance_id(c_id, prefix)
    initial_state = Flow.initial_state(flow)
    params = Map.merge(params, %{"instance_id" => instance_id, "state_id" => initial_state.id})

    c_type
    |> build_assoc(:instances, creator: current_user)
    |> Instance.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, content} ->
        Task.start_link(fn -> create_or_update_counter(c_type) end)
        Task.start_link(fn -> create_initial_version(current_user, content) end)

        create_instance_approval_systems(c_type, content)

        Repo.preload(content, [
          :content_type,
          :state,
          :vendor,
          {:instance_approval_systems, :approver}
        ])

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Relate instace with approval system on creation
  ## Params
  * content_type - A content type struct
  * content - a Instance struct
  """
  @spec create_instance_approval_systems(ContentType.t(), Instance.t()) :: :ok
  def create_instance_approval_systems(content_type, content) do
    with %ContentType{flow: %Flow{approval_systems: approval_systems}} <-
           Repo.preload(content_type, [{:flow, :approval_systems}]) do
      Enum.each(approval_systems, fn x ->
        # Task.start_link(fn ->
        #   Notifications.create_notification(
        #    %{"recipient_id" x.approver_id,
        #    "actor_id"=> content.creator_id,
        #     "assigned_as_approver",
        #     x.id,
        #     ApprovalSystem
        #   )
        # end)

        create_instance_approval_system(%{
          instance_id: content.id,
          approval_system_id: x.id
        })
      end)
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

  @doc """
  To approve an instance with associated approval systems
  ## Parameters
  * User - User struct
  * Instance - instance struct
  """
  @spec approve_instance(User.t(), Instance.t()) :: Instance.t() | {:error, :no_permission}
  def approve_instance(
        %User{id: user_id},
        %Instance{
          state: %State{
            approval_system:
              %ApprovalSystem{approver: %User{id: user_id}, post_state: post_state} =
                approval_system
          }
        } = instance
      ) do
    instance
    |> Instance.update_state_changeset(%{state_id: post_state.id})
    |> Repo.update()
    |> case do
      {:ok, instance} ->
        update_instance_approval_system(instance, approval_system, %{
          flag: true,
          approved_at: Timex.now()
        })

        instance =
          instance |> Repo.unpreload(:state) |> Repo.unpreload(:instance_approval_systems)

        Repo.preload(instance, [
          :creator,
          {:content_type, :layout},
          {:versions, :author},
          {:instance_approval_systems, :approver},
          state: [approval_system: [:post_state, :approver]]
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  def approve_instance(_, _), do: {:error, :no_permission}

  @doc """
  To reject an instance with associated approval systems
  ## Parameters
  * User - User struct
  * Instance - instance struct
  """
  # TODO-  Approval System log
  @spec reject_instance(User.t(), Instance.t()) :: Instance.t() | {:error, :no_permission}
  def reject_instance(
        %User{id: user_id},
        %Instance{
          state: %State{
            rejection_system:
              %ApprovalSystem{approver: %User{id: user_id}, pre_state: pre_state} =
                approval_system
          }
        } = instance
      ) do
    instance
    |> Instance.update_state_changeset(%{state_id: pre_state.id})
    |> Repo.update()
    |> case do
      {:ok, instance} ->
        update_instance_approval_system(instance, approval_system, %{
          flag: false,
          rejected_at: Timex.now()
        })

        instance =
          instance |> Repo.unpreload(:state) |> Repo.unpreload(:instance_approval_systems)

        Repo.preload(instance, [
          :creator,
          {:content_type, :layout},
          {:versions, :author},
          {:instance_approval_systems, :approver},
          state: [approval_system: [:post_state, :approver]]
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  def reject_instance(_, _), do: {:error, :no_permission}

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
  # TODO - improve tests
  @spec instance_index_of_an_organisation(User.t(), map) :: map
  def instance_index_of_an_organisation(%{organisation_id: org_id}, params) do
    query =
      from(i in Instance,
        join: u in User,
        where: u.organisation_id == ^org_id and i.creator_id == u.id,
        order_by: [desc: i.id],
        preload: [:content_type, :state, :vendor, {:instance_approval_systems, :approver}]
      )

    Repo.paginate(query, params)
  end

  @doc """
  List all instances under a content types.
  """
  # TODO - improve tests
  @spec instance_index(binary, map) :: map
  def instance_index(<<_::288>> = c_type_id, params) do
    query =
      from(i in Instance,
        join: ct in ContentType,
        where: ct.id == ^c_type_id and i.content_type_id == ct.id,
        order_by: [desc: i.id],
        preload: [:content_type, :state, :vendor, {:instance_approval_systems, :approver}]
      )

    Repo.paginate(query, params)
  end

  def instance_index(_, _), do: {:error, :invalid_id}

  @doc """
  Get an instance from its UUID.
  """
  # TODO - improve tests
  @spec get_instance(binary, User.t()) :: Instance.t()
  def get_instance(<<_::288>> = id, %{organisation_id: org_id}) do
    query =
      from(i in Instance,
        where: i.id == ^id,
        join: c in ContentType,
        where: c.id == i.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %Instance{} = instance -> instance
      _ -> {:error, :invalid_id, "Instance"}
    end
  end

  def get_instance(_, %{organisation_id: _}), do: {:error, :invalid_id}
  def get_instance(_, _), do: {:error, :fake}

  @doc """
  Show an instance.
  """
  # TODO - improve tests
  @spec show_instance(binary, User.t()) ::
          %Instance{creator: User.t(), content_type: ContentType.t(), state: State.t()} | nil
  def show_instance(instance_id, user) do
    with %Instance{} = instance <- get_instance(instance_id, user) do
      instance
      |> Repo.preload([
        :creator,
        {:content_type, :layout},
        {:versions, :author},
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
  # TODO - write tests
  @spec get_built_document(Instance.t()) :: Instance.t() | nil
  def get_built_document(%{id: id, instance_id: instance_id} = instance) do
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
        doc_url = "uploads/contents/#{instance_id}/final.pdf"
        Map.put(instance, :build, doc_url)
    end
  end

  def get_built_document(nil), do: nil

  @doc """
  Update an instance and creates updated version
  the instance is only available to edit if its editable field is true
  ## Parameters
  * `old_instance` - Instance struct before updation
  * `current_user` - User struct
  * `params` - Map contains attributes
  """
  # TODO - improve tests
  @spec update_instance(Instance.t(), User.t(), map) ::
          %Instance{content_type: ContentType.t(), state: State.t(), creator: Creator.t()}
          | {:error, Ecto.Changeset.t()}
  def update_instance(
        %Instance{editable: true} = old_instance,
        %User{id: id},
        params
      ) do
    old_instance
    |> Instance.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:ok, instance} ->
        instance
        |> Repo.preload([
          :creator,
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

  def update_instance(
        %Instance{editable: false},
        _current_user,
        _params
      ) do
    {:error, :cant_update}
  end

  def update_instance(_, _, _), do: {:error, :cant_update}

  # Create a new version with old data, when an instance is updated.
  # The previous data will be stored in the versions. Latest one will
  # be in the content.
  # A new version is added only if there is any difference in either the
  # raw or serialized fields of the instances.
  @spec create_version(User.t(), Instance.t(), map()) ::
          {:ok, Version.t()} | {:error, Ecto.Changeset.t()}
  def create_version(current_user, new_instance, params) do
    old_instance = get_last_version(new_instance)

    case instance_updated?(old_instance, new_instance) do
      true ->
        params = create_version_params(new_instance, params)

        current_user
        |> build_assoc(:instance_versions, content: new_instance)
        |> Version.changeset(params)
        |> Spur.insert()

      false ->
        nil
    end
  end

  defp get_last_version(%{id: id}) do
    query = from(v in Version, where: v.content_id == ^id)

    query
    |> last(:inserted_at)
    |> Repo.one()
  end

  defp get_last_version(_), do: nil
  # Create the params to create a new version.
  # @spec create_version_params(Instance.t(), map()) :: map
  defp create_version_params(%Instance{id: id} = instance, params) do
    query =
      from(v in Version,
        where: v.content_id == ^id,
        order_by: [desc: v.inserted_at],
        limit: 1,
        select: v.version_number
      )

    version =
      query
      |> Repo.one()
      |> case do
        nil ->
          1

        version ->
          version + 1
      end

    naration = params["naration"] || "Version-#{version / 10}"
    instance |> Map.from_struct() |> Map.merge(%{version_number: version, naration: naration})
  end

  defp create_version_params(_, params), do: params

  # Checks whether the raw and serialzed of old and new instances are same or not.
  # If they are both the same, returns false, else returns true
  # @spec instance_updated?(Instance.t(), Instance.t()) :: boolean
  defp instance_updated?(%{raw: o_raw, serialized: o_map}, %{raw: n_raw, serialized: n_map}) do
    !(o_raw === n_raw && o_map === n_map)
  end

  defp instance_updated?(_old_instance, _new_instance), do: true

  @doc """
  Update instance's state if the flow IDs of both
  the new state and the instance's content type are same.
  """
  # TODO - impove tests
  @spec update_instance_state(User.t(), Instance.t(), State.t()) ::
          Instance.t() | {:error, Ecto.Changeset.t()} | {:error, :wrong_flow}
  def update_instance_state(%{id: user_id}, instance, %{
        id: state_id,
        state: new_state,
        flow_id: flow_id
      }) do
    case Repo.preload(instance, [:content_type, :state]) do
      %{content_type: %{flow_id: f_id}, state: %{state: state}} ->
        if flow_id == f_id do
          instance_state_upadate(instance, user_id, state_id, state, new_state)
        else
          {:error, :wrong_flow}
        end

      _ ->
        {:error, :not_sufficient}
    end
  end

  def update_instance_state(_, _, _), do: {:error, :not_sufficient}

  @doc """
  Update instance's state. Also add the from and to state of in the activity meta.
  """
  # TODO - write tests
  @spec instance_state_upadate(Instance.t(), integer, integer, String.t(), String.t()) ::
          Instance.t() | {:error, Ecto.Changeset.t()}
  def instance_state_upadate(instance, user_id, state_id, old_state, new_state) do
    instance
    |> Instance.update_state_changeset(%{state_id: state_id})
    |> Spur.update(%{
      actor: "#{user_id}",
      object: "Instance-State:#{instance.id}",
      meta: %{from: old_state, to: new_state}
    })
    |> case do
      {:ok, instance} ->
        instance
        |> Repo.preload([:creator, [{:content_type, :layout}], :state])
        |> get_built_document()

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete an instance.
  """
  # TODO - write tests
  @spec delete_instance(Instance.t(), User.t()) ::
          {:ok, Instance.t()} | {:error, Ecto.Changeset.t()}
  def delete_instance(instance, %User{id: id}) do
    Spur.delete(instance, %{actor: "#{id}", meta: instance})
  end

  def delete_instance(_, _), do: {:error, :fake}

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
  Create a theme.
  """
  # TODO Improve tests
  @spec create_theme(User.t(), map) :: {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def create_theme(%{organisation_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:themes)
    |> Theme.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, theme} ->
        theme_file_upload(theme, params)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Upload theme file.
  """
  # TODO - write tests
  @spec theme_file_upload(Theme.t(), map) :: {:ok, %Theme{}} | {:error, Ecto.Changeset.t()}
  def theme_file_upload(theme, %{"file" => _} = params) do
    theme |> Theme.file_changeset(params) |> Repo.update()
  end

  def theme_file_upload(theme, _params) do
    {:ok, theme}
  end

  @doc """
  Index of themes inside current user's organisation.
  """
  # TODO - improve tests
  @spec theme_index(User.t(), map) :: map
  def theme_index(%User{organisation_id: org_id}, params) do
    query = from(t in Theme, where: t.organisation_id == ^org_id, order_by: [desc: t.id])
    Repo.paginate(query, params)
  end

  @doc """
  Get a theme from its UUID.
  """
  # TODO - improve test
  @spec get_theme(binary, User.t()) :: Theme.t() | nil
  def get_theme(theme_uuid, %{organisation_id: org_id}) do
    Repo.get_by(Theme, id: theme_uuid, organisation_id: org_id)
  end

  @doc """
  Show a theme.
  """
  # TODO - improve test
  @spec show_theme(binary, User.t()) :: %Theme{creator: User.t()} | nil
  def show_theme(theme_uuid, user) do
    theme_uuid |> get_theme(user) |> Repo.preload([:creator])
  end

  @doc """
  Update a theme.
  """
  # TODO - improve test
  @spec update_theme(Theme.t(), User.t(), map) :: {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def update_theme(theme, %User{id: id}, params) do
    theme |> Theme.update_changeset(params) |> Spur.update(%{actor: "#{id}"})
  end

  @doc """
  Delete a theme.
  """
  # TODO - improve test
  @spec delete_theme(Theme.t(), User.t()) :: {:ok, Theme.t()}
  def delete_theme(theme, %User{id: id}) do
    Spur.delete(theme, %{actor: "#{id}", meta: theme})
  end

  @doc """
  Create a data template.
  """
  @spec create_data_template(User.t(), ContentType.t(), map) ::
          {:ok, DataTemplate.t()} | {:error, Ecto.Changeset.t()}
  # TODO - imprvove tests
  def create_data_template(%User{id: user_id}, %ContentType{id: c_type_id}, params) do
    params = Map.merge(params, %{"creator_id" => user_id, "content_type_id" => c_type_id})

    %DataTemplate{}
    |> DataTemplate.changeset(params)
    |> Spur.insert()
  end

  def create_data_template(%User{}, _, _), do: {:error, :invalid_id, "ContentType"}
  def create_data_template(_, _, _), do: {:error, :fake}

  @doc """
  List all data templates under a content types.
  """
  # TODO - imprvove tests
  @spec data_template_index(binary, map) :: map
  def data_template_index(<<_::288>> = c_type_id, params) do
    query =
      from(dt in DataTemplate,
        join: ct in ContentType,
        where: ct.id == ^c_type_id and dt.content_type_id == ct.id,
        order_by: [desc: dt.id],
        preload: [:content_type]
      )

    Repo.paginate(query, params)
  end

  def data_template_index(_, _), do: {:error, :invalid_id, "ContentType"}

  @doc """
  List all data templates under current user's organisation.
  """
  # TODO - imprvove tests
  @spec data_templates_index_of_an_organisation(User.t(), map) :: map
  def data_templates_index_of_an_organisation(%{organisation_id: org_id}, params) do
    query =
      from(dt in DataTemplate,
        join: u in User,
        where: u.organisation_id == ^org_id and dt.creator_id == u.id,
        order_by: [desc: dt.id],
        preload: [:content_type]
      )

    Repo.paginate(query, params)
  end

  def data_templates_index_of_an_organisation(_, _), do: {:error, :fake}

  @doc """
  Get a data template from its uuid and organisation ID of user.
  """
  # TODO - imprvove tests
  @spec get_d_template(User.t(), Ecto.UUID.t()) :: DataTemplat.t() | nil
  def get_d_template(%User{organisation_id: org_id}, <<_::288>> = d_temp_id) do
    query =
      from(d in DataTemplate,
        where: d.id == ^d_temp_id,
        join: c in ContentType,
        where: c.id == d.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %DataTemplate{} = data_template -> data_template
      _ -> {:error, :invalid_id, "DataTemplate"}
    end
  end

  def get_d_template(%{organisation_id: _}, _), do: {:error, :invalid_id, "DataTemplate"}
  def get_d_template(_, <<_::288>>), do: {:error, :fake}
  def get_d_template(_, _), do: {:error, :fake}

  @doc """
  Show a data template.
  """
  # TODO - imprvove tests
  @spec show_d_template(User.t(), Ecto.UUID.t()) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()} | nil
  def show_d_template(user, d_temp_id) do
    with %DataTemplate{} = data_template <- get_d_template(user, d_temp_id) do
      Repo.preload(data_template, [:creator, :content_type])
    end
  end

  @doc """
  Update a data template
  """
  # TODO - imprvove tests
  @spec update_data_template(DataTemplate.t(), User.t(), map) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()}
          | {:error, Ecto.Changeset.t()}
  def update_data_template(d_temp, %User{id: id}, params) do
    d_temp
    |> DataTemplate.changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:ok, d_temp} ->
        Repo.preload(d_temp, [:creator, :content_type])

      {:error, _} = changeset ->
        changeset
    end
  end

  def update_data_template(_, _, _), do: {:error, :fake}

  @doc """
  Delete a data template
  """
  # TODO - imprvove tests
  @spec delete_data_template(DataTemplate.t(), User.t()) :: {:ok, DataTemplate.t()}
  def delete_data_template(d_temp, %User{id: id}) do
    Spur.delete(d_temp, %{actor: "#{id}", meta: d_temp})
  end

  @doc """
  Create an asset.
  """
  # TODO - imprvove tests
  @spec create_asset(User.t(), map) :: {:ok, Asset.t()}
  def create_asset(%{organisation_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:assets)
    |> Asset.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, asset} ->
        asset_file_upload(asset, params)

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_asset(_, _), do: {:error, :fake}

  @doc """
  Upload asset file.
  """
  # TODO - write tests
  @spec asset_file_upload(Asset.t(), map) :: {:ok, %Asset{}} | {:error, Ecto.Changeset.t()}
  def asset_file_upload(asset, %{"file" => _} = params) do
    asset |> Asset.file_changeset(params) |> Repo.update()
  end

  def asset_file_upload(asset, _params) do
    {:ok, asset}
  end

  @doc """
  Index of all assets in an organisation.
  """
  # TODO - improve tests
  @spec asset_index(integer, map) :: map
  def asset_index(%{organisation_id: organisation_id}, params) do
    query =
      from(a in Asset,
        where: a.organisation_id == ^organisation_id,
        order_by: [desc: a.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def asset_index(_, _), do: {:error, :fake}

  @doc """
  Show an asset.
  """
  # TODO - improve tests
  @spec show_asset(binary, User.t()) :: %Asset{creator: User.t()}
  def show_asset(asset_id, user) do
    with %Asset{} = asset <-
           get_asset(asset_id, user) do
      Repo.preload(asset, [:creator])
    end
  end

  @doc """
  Get an asset from its UUID.
  """
  # TODO - improve tests
  @spec get_asset(binary, User.t()) :: Asset.t()
  def get_asset(<<_::288>> = id, %{organisation_id: org_id}) do
    case Repo.get_by(Asset, id: id, organisation_id: org_id) do
      %Asset{} = asset -> asset
      _ -> {:error, :invalid_id}
    end
  end

  def get_asset(<<_::288>>, _), do: {:error, :fake}
  def get_asset(_, %{organisation_id: _}), do: {:error, :invalid_id}

  @doc """
  Update an asset.
  """
  # TODO - improve tests
  @spec update_asset(Asset.t(), User.t(), map) :: {:ok, Asset.t()}
  def update_asset(asset, %User{id: id}, params) do
    asset |> Asset.update_changeset(params) |> Spur.update(%{actor: "#{id}"})
  end

  @doc """
  Delete an asset.
  """
  @spec delete_asset(Asset.t(), User.t()) :: {:ok, Asset.t()}
  def delete_asset(asset, %User{id: id}) do
    Spur.delete(asset, %{actor: "#{id}", meta: asset})
  end

  @doc """
  Preload assets of a layout.
  """
  # TODO - write tests
  @spec preload_asset(Layout.t()) :: Layout.t()
  def preload_asset(%Layout{} = layout) do
    Repo.preload(layout, [:assets])
  end

  def preload_asset(_), do: {:error, :not_sufficient}

  @doc """
  Build a PDF document.
  """
  # TODO - write tests
  @spec build_doc(Instance.t(), Layout.t()) :: {any, integer}
  def build_doc(%Instance{instance_id: u_id, content_type: c_type} = instance, %Layout{
        slug: slug,
        assets: assets
      }) do
    File.mkdir_p("uploads/contents/#{u_id}")
    System.cmd("cp", ["-a", "lib/slugs/#{slug}/.", "uploads/contents/#{u_id}"])
    task = Task.async(fn -> generate_qr(instance) end)
    Task.start(fn -> move_old_builds(u_id) end)
    c_type = Repo.preload(c_type, [:fields])

    header =
      Enum.reduce(c_type.fields, "--- \n", fn x, acc ->
        find_header_values(x, instance.serialized, acc)
      end)

    header = Enum.reduce(assets, header, fn x, acc -> find_header_values(x, acc) end)
    qr_code = Task.await(task)
    page_title = instance.serialized["title"]

    header =
      header
      |> concat_strings("qrcode: #{qr_code} \n")
      |> concat_strings("path: uploads/contents/#{u_id}\n")
      |> concat_strings("title: #{page_title}\n")
      |> concat_strings("id: #{u_id}\n")
      |> concat_strings("--- \n")

    content = """
    #{header}
    #{instance.raw}
    """

    File.write("uploads/contents/#{u_id}/content.md", content)

    pandoc_commands = [
      "uploads/contents/#{u_id}/content.md",
      "--template=uploads/contents/#{u_id}/template.tex",
      "--pdf-engine=xelatex",
      "-o",
      "uploads/contents/#{u_id}/final.pdf"
    ]

    System.cmd("pandoc", pandoc_commands)
  end

  # Find the header values for the content.md file from the serialized data of an instance.
  @spec find_header_values(ContentTypeField.t(), map, String.t()) :: String.t()
  defp find_header_values(%ContentTypeField{name: key}, serialized, acc) do
    serialized
    |> Enum.find(fn {k, _} -> k == key end)
    |> case do
      nil ->
        acc

      {_, value} ->
        concat_strings(acc, "#{key}: #{value} \n")
    end
  end

  # Find the header values for the content.md file from the assets of the layout used.
  @spec find_header_values(Asset.t(), String.t()) :: String.t()
  defp find_header_values(%Asset{name: name, file: file} = asset, acc) do
    <<_first::utf8, rest::binary>> = generate_url(AssetUploader, file, asset)
    concat_strings(acc, "#{name}: #{rest} \n")
  end

  # Generate url.
  @spec generate_url(any, String.t(), map) :: String.t()
  defp generate_url(uploader, file, scope) do
    uploader.url({file, scope}, signed: true)
  end

  # Generate QR code with the UUID of the given Instance.
  @spec generate_qr(Instance.t()) :: String.t()
  defp generate_qr(%Instance{id: id, instance_id: i_id}) do
    qr_code_png =
      id
      |> EQRCode.encode()
      |> EQRCode.png()

    destination = "uploads/contents/#{i_id}/qr.png"
    File.write(destination, qr_code_png, [:binary])
    destination
  end

  # Concat two strings.
  @spec concat_strings(String.t(), String.t()) :: String.t()
  defp concat_strings(string1, string2) do
    string1 <> string2
  end

  # Move old builds to the history folder
  @spec move_old_builds(String.t()) :: {:ok, non_neg_integer()}
  defp move_old_builds(u_id) do
    path = "uploads/contents/#{u_id}/"
    history_path = concat_strings(path, "history/")
    old_file = concat_strings(path, "final.pdf")
    File.mkdir_p(history_path)

    history_file =
      history_path
      |> File.ls!()
      |> Enum.sort(:desc)
      |> case do
        ["final-" <> version | _] ->
          ["v" <> version | _] = String.split(version, ".pdf")
          version = version |> String.to_integer() |> add(1)
          concat_strings(history_path, "final-v#{version}.pdf")

        [] ->
          concat_strings(history_path, "final-v1.pdf")
      end

    File.copy(old_file, history_file)
  end

  @doc """
  Insert the build history of the given instance.
  """
  # TODO - write tests
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
  # TODO - write tests
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
  Create a Block
  """
  # TODO - write tests
  @spec create_block(User.t(), map) :: Block.t()
  def create_block(%{organisation_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:blocks)
    |> Block.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, block} ->
        block

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_block(_, _), do: {:error, :fake}

  @doc """
  Get a block by id
  """
  # TODO - write tests
  @spec get_block(Ecto.UUID.t(), User.t()) :: Block.t()
  def get_block(<<_::288>> = id, %{organisation_id: org_id}) do
    case Repo.get_by(Block, id: id, organisation_id: org_id) do
      %Block{} = block -> block
      _ -> {:error, :invalid_id, "Block"}
    end
  end

  def get_block(<<_::288>>, _), do: {:error, :fake}
  def get_block(_, %{organisation_id: _}), do: {:error, :invalid_id, "Block"}

  @doc """
  Update a block
  """
  # TODO - write tests
  def update_block(%User{id: id}, %Block{} = block, params) do
    block
    |> Block.changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:ok, block} ->
        block

      {:error, _} = changeset ->
        changeset
    end
  end

  def update_block(_, _, _), do: {:error, :fake}

  @doc """
  Delete a block
  """
  # TODO - write tests
  def delete_block(%Block{} = block) do
    Repo.delete(block)
  end

  @doc """
  Function to generate charts from diffrent endpoints as per input example api: https://quickchart.io/chart/create
  """
  # TODO - write tests
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
        body: Poison.encode!(dataset),
        headers: [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
      )

    Poison.decode!(response_body)
  end

  def generate_chart(%{"dataset" => dataset, "api_route" => api_route, "endpoint" => "blocks_api"}) do
    %HTTPoison.Response{body: response_body} =
      HTTPoison.post!(
        api_route,
        Poison.encode!(dataset),
        [{"Accept", "application./json"}, {"Content-Type", "application/json"}]
      )

    Poison.decode!(response_body)
  end

  def generate_chart(_params) do
    %{"status" => false, "error" => "invalid endpoint"}
  end

  @doc """
  Generate tex code for the chart
  """
  # TODO - write tests
  @spec generate_tex_chart(map) :: <<_::64, _::_*8>>
  def generate_tex_chart(%{"dataset" => dataset, "btype" => "gantt"}) do
    generate_tex_gantt_chart(dataset)
  end

  def generate_tex_chart(%{"input" => input, "btype" => "gantt", "name" => name}) do
    generate_gnu_gantt_chart(input, name)
  end

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
      File.read!("lib/slugs/gantt_chart/gnuplot_gantt.plt")
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
  Create a field type
  """
  # TODO - write tests
  @spec create_field_type(User.t(), map) :: {:ok, FieldType.t()}
  def create_field_type(%User{} = current_user, params) do
    current_user
    |> build_assoc(:field_types)
    |> FieldType.changeset(params)
    |> Repo.insert()
  end

  def create_field_type(_, _), do: {:error, :fake}

  @doc """
  Index of all field types.
  """
  # TODO - write tests
  @spec field_type_index(map) :: map
  def field_type_index(params) do
    query = from(ft in FieldType, order_by: [desc: ft.id])
    Repo.paginate(query, params)
  end

  @doc """
  Get a field type from its UUID.
  """
  # TODO - write tests
  @spec get_field_type(binary, User.t()) :: FieldType.t()
  def get_field_type(<<_::288>> = field_type_id, %{organisation_id: org_id}) do
    query =
      from(ft in FieldType,
        where: ft.id == ^field_type_id,
        join: u in User,
        where: u.id == ft.creator_id and u.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %FieldType{} = field_type -> field_type
      _ -> {:error, :invalid_id, "FieldType"}
    end

    # Repo.get_by(FieldType, uuid: field_type_uuid, organisation_id: org_id)
  end

  def get_field_type(_, %{organisation_id: _}), do: {:error, :invalid_id, "FieldType"}
  def get_field_type(_, _), do: {:error, :fake}

  @doc """
  Update a field type
  """
  # TODO - write tests
  @spec update_field_type(FieldType.t(), map) :: FieldType.t() | {:error, Ecto.Changeset.t()}
  def update_field_type(field_type, params) do
    field_type
    |> FieldType.changeset(params)
    |> Repo.update()
  end

  @doc """
  Deleta a field type
  """
  # TODO - write tests
  @spec delete_field_type(FieldType.t()) :: {:ok, FieldType.t()} | {:error, Ecto.Changeset.t()}
  def delete_field_type(field_type) do
    field_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :fields,
      message:
        "Cannot delete the field type. Some Content types depend on this field type. Update those content types and then try again.!"
    )
    |> Repo.delete()
  end

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
  Create a background job for data template bulk import.
  """
  @spec insert_data_template_bulk_import_work(binary, binary, map, Plug.Uploap.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_data_template_bulk_import_work(user_id, c_type_id, mapping \\ %{}, file)

  def insert_data_template_bulk_import_work(
        <<_::288>> = user_id,
        <<_::288>> = c_type_id,
        mapping,
        %Plug.Upload{
          filename: filename,
          path: path
        }
      ) do
    File.mkdir_p("temp/bulk_import_source/d_template")
    dest_path = "temp/bulk_import_source/d_template/#{filename}"
    System.cmd("cp", [path, dest_path])

    data = %{
      user_id: user_id,
      c_type_uuid: c_type_id,
      mapping: mapping,
      file: dest_path
    }

    create_bulk_job(data, ["data template"])
  end

  def insert_data_template_bulk_import_work(_, <<_::288>>, _mapping, %Plug.Upload{
        filename: _filename,
        path: _path
      }),
      do: {:error, :fake}

  def insert_data_template_bulk_import_work(<<_::288>>, _, _mapping, %Plug.Upload{
        filename: _filename,
        path: _path
      }),
      do: {:error, :invalid_id, "ContentType"}

  def insert_data_template_bulk_import_work(_, _, _, _), do: {:error, :invalid_data}

  @doc """
  Creates a background job for block template bulk import.
  """
  @spec insert_block_template_bulk_import_work(User.t(), map, Plug.Uploap.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_block_template_bulk_import_work(user, mapping \\ %{}, file)

  def insert_block_template_bulk_import_work(%User{id: user_id}, mapping, %Plug.Upload{
        filename: filename,
        path: path
      }) do
    File.mkdir_p("temp/bulk_import_source/b_template")
    dest_path = "temp/bulk_import_source/b_template/#{filename}"
    System.cmd("cp", [path, dest_path])

    data = %{
      user_id: user_id,
      mapping: mapping,
      file: dest_path
    }

    create_bulk_job(data, ["block template"])
  end

  # def insert_block_template_bulk_import_work(_, _, %Plug.Upload{filename: _, path: _}),
  #   do: {:error, :fake}

  def insert_block_template_bulk_import_work(_, _, _), do: {:error, :invalid_data}

  @doc """
  Creates a background job to run a pipeline.
  """
  # TODO - write tests
  @spec create_pipeline_job(TriggerHistory.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def create_pipeline_job(%TriggerHistory{} = trigger_history) do
    create_bulk_job(trigger_history, ["pipeline_job"])
  end

  def create_pipeline_job(_, _), do: nil

  defp create_bulk_job(args, tags \\ []) do
    args
    |> BulkWorker.new(tags: tags)
    |> Oban.insert()
  end

  @doc """
  Bulk build function.
  """
  # TODO - write tests
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
    |> decode_csv(mapping_keys)
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
    serialized = update_keys(serialized, mapping)
    params = do_create_instance_params(serialized, d_temp)
    type = Instance.types()[:bulk_build]
    params = Map.merge(params, %{"type" => type, "state_id" => state.id})
    create_instance_for_bulk_build(current_user, c_type, params)
  end

  @doc """
  Generate params to create instance.
  """
  # TODO - write tests
  @spec do_create_instance_params(map, DataTemplate.t()) :: map
  def do_create_instance_params(serialized, %{title_template: title_temp, data: template}) do
    title =
      Enum.reduce(serialized, title_temp, fn {k, v}, acc ->
        WraftDoc.DocConversion.replace_content(k, v, acc)
      end)

    serialized = Map.put(serialized, "title", title)

    raw =
      Enum.reduce(serialized, template, fn {k, v}, acc ->
        WraftDoc.DocConversion.replace_content(k, v, acc)
      end)

    %{"raw" => raw, "serialized" => serialized}
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
  # TODO - write tests
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
  # TODO - write tests
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

  # Change the Keys of the CSV decoded map to the values of the mapping.
  @spec update_keys(map, map) :: map
  defp update_keys(map, mapping) do
    # new_map =
    Enum.reduce(mapping, %{}, fn {k, v}, acc ->
      value = Map.get(map, k)
      Map.put(acc, v, value)
    end)

    # keys = mapping |> Map.keys()
    # map |> Map.drop(keys) |> Map.merge(new_map)
  end

  @doc """
  Creates data templates in bulk from the file given.
  """
  ## TODO - improve tests
  @spec data_template_bulk_insert(User.t(), ContentType.t(), map, String.t()) ::
          [{:ok, DataTemplate.t()}] | {:error, :not_found}
  def data_template_bulk_insert(%User{} = current_user, %ContentType{} = c_type, mapping, path) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = Map.keys(mapping)

    path
    |> decode_csv(mapping_keys)
    |> Stream.map(fn x -> bulk_d_temp_creation(x, current_user, c_type, mapping) end)
    |> Enum.to_list()
  end

  def data_template_bulk_insert(_, _, _, _), do: {:error, :not_found}

  @spec bulk_d_temp_creation(map, User.t(), ContentType.t(), map) :: {:ok, DataTemplate.t()}
  defp bulk_d_temp_creation(data, user, c_type, mapping) do
    params = update_keys(data, mapping)
    create_data_template(user, c_type, params)
  end

  @doc """
  Creates block templates in bulk from the file given.
  """
  @spec block_template_bulk_insert(User.t(), map, String.t()) ::
          [{:ok, BlockTemplate.t()}] | {:error, :not_found}
  ## TODO - improve tests
  def block_template_bulk_insert(%User{} = current_user, mapping, path) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = Map.keys(mapping)

    path
    |> decode_csv(mapping_keys)
    |> Stream.map(fn x -> bulk_b_temp_creation(x, current_user, mapping) end)
    |> Enum.to_list()
  end

  def block_template_bulk_insert(_, _, _), do: {:error, :not_found}

  # Decode the given CSV file using the headers values
  # First argument is the path of the file
  # Second argument is the headers.
  @spec decode_csv(String.t(), list) :: list
  defp decode_csv(path, mapping_keys) do
    path
    |> File.stream!()
    |> Stream.drop(1)
    |> CSV.decode!(headers: mapping_keys)
    |> Enum.to_list()
  end

  @spec bulk_b_temp_creation(map, User.t(), map) :: BlockTemplate.t()
  defp bulk_b_temp_creation(data, user, mapping) do
    params = update_keys(data, mapping)
    create_block_template(user, params)
  end

  @doc """
  Create a block template
  """
  # TODO - improve tests
  @spec create_block_template(User.t(), map) :: BlockTemplate.t()
  def create_block_template(%{organisation_id: org_id} = current_user, params) do
    current_user
    |> build_assoc(:block_templates, organisation_id: org_id)
    |> BlockTemplate.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, block_template} ->
        block_template

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_block_template(_, _), do: {:error, :fake}

  @doc """
  Get a block template by its uuid
  """
  # TODO - write tests
  @spec get_block_template(Ecto.UUID.t(), User.t()) :: BlockTemplate.t()
  def get_block_template(<<_::288>> = id, %{organisation_id: org_id}) do
    case Repo.get_by(BlockTemplate, id: id, organisation_id: org_id) do
      %BlockTemplate{} = block_template -> block_template
      _ -> {:error, :invalid_id, "BlockTemplate"}
    end
  end

  def get_block_template(<<_::288>>, _), do: {:error, :invalid_id, "BlockTemplate"}
  def get_block_template(_, %{organisation_id: _org_id}), do: {:error, :fake}
  def get_block_template(_, _), do: {:error, :invalid_id, "BlockTemplate"}

  @doc """
  Updates a block template
  """
  # TODO - write tests
  @spec update_block_template(User.t(), BlockTemplate.t(), map) :: BlockTemplate.t()
  def update_block_template(%User{id: id}, block_template, params) do
    block_template
    |> BlockTemplate.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, block_template} ->
        block_template
    end
  end

  def update_block_template(_, _, _), do: {:error, :fake}

  @doc """
  Delete a block template by uuid
  """
  # TODO - write tests
  @spec delete_block_template(User.t(), BlockTemplate.t()) :: BlockTemplate.t()
  def delete_block_template(%User{id: id}, %BlockTemplate{} = block_template) do
    Spur.delete(block_template, %{actor: "#{id}", meta: block_template})
  end

  def delete_block_template(_, _), do: {:error, :fake}

  @doc """
  Index of a block template by organisation
  """
  # TODO - write tests
  @spec block_template_index(User.t(), map) :: List.t()
  def block_template_index(%{organisation_id: org_id}, params) do
    query =
      from(bt in BlockTemplate, where: bt.organisation_id == ^org_id, order_by: [desc: bt.id])

    Repo.paginate(query, params)
  end

  @doc """
  Create a comment
  """
  # TODO - improve tests
  def create_comment(%{organisation_id: org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)

    current_user
    |> build_assoc(:comments)
    |> Comment.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        Repo.preload(comment, [{:user, :profile}])

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_comment(_, _), do: {:error, :fake}

  @doc """
  Get a comment by uuid.
  """
  # TODO - improve tests
  @spec get_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def get_comment(<<_::288>> = id, %{organisation_id: org_id}) do
    case Repo.get_by(Comment, id: id, organisation_id: org_id) do
      %Comment{} = comment -> comment
      _ -> {:error, :invalid_id, "Comment"}
    end
  end

  def get_comment(<<_::288>>, _), do: {:error, :fake}
  def get_comment(_, %{organisation_id: _}), do: {:error, :invalid_id, "Comment"}
  def get_comment(_, _), do: {:error, :invalid_id, "Comment"}

  @doc """
  Fetch a comment and all its details.
  """
  # TODO - improve tests
  @spec show_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def show_comment(id, user) do
    with %Comment{} = comment <- get_comment(id, user) do
      Repo.preload(comment, [{:user, :profile}])
    end
  end

  @doc """
  Updates a comment
  """
  @spec update_comment(Comment.t(), map) :: Comment.t()
  def update_comment(comment, params) do
    comment
    |> Comment.changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, comment} ->
        Repo.preload(comment, [{:user, :profile}])
    end
  end

  @doc """
  Deletes a coment
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Comments under a master
  """
  # TODO - improve tests
  def comment_index(%{organisation_id: org_id}, %{"master_id" => master_id} = params) do
    query =
      from(c in Comment,
        where: c.organisation_id == ^org_id,
        where: c.master_id == ^master_id,
        where: c.is_parent == true,
        order_by: [desc: c.inserted_at],
        preload: [{:user, :profile}]
      )

    Repo.paginate(query, params)
  end

  def comment_index(%{organisation_id: _}, _), do: {:error, :invalid_data}
  def comment_index(_, %{"master_id" => _}), do: {:error, :fake}
  def comment_index(_, _), do: {:error, :invalid_data}

  @doc """
   Replies under a comment
  """
  # TODO - improve tests
  @spec comment_replies(%{organisation_id: any}, map) :: Scrivener.Page.t()
  def comment_replies(
        %{organisation_id: org_id} = user,
        %{"master_id" => master_id, "comment_id" => comment_id} = params
      ) do
    with %Comment{id: parent_id} <- get_comment(comment_id, user) do
      query =
        from(c in Comment,
          where: c.organisation_id == ^org_id,
          where: c.master_id == ^master_id,
          where: c.is_parent == false,
          where: c.parent_id == ^parent_id,
          order_by: [desc: c.inserted_at],
          preload: [{:user, :profile}]
        )

      Repo.paginate(query, params)
    end
  end

  def comment_replies(_, %{"master_id" => _, "comment_id" => _}), do: {:error, :fake}
  def comment_replies(%{organisation_id: _}, _), do: {:error, :invalid_data}
  def comment_replies(_, _), do: {:error, :invalid_data}

  @doc """
  Create a pipeline.
  """
  @spec create_pipeline(User.t(), map) :: Pipeline.t() | {:error, Ecto.Changeset.t()}
  def create_pipeline(%{organisation_id: org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)

    current_user
    |> build_assoc(:pipelines)
    |> Pipeline.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, pipeline} ->
        create_pipe_stages(current_user, pipeline, params)

        Repo.preload(pipeline,
          stages: [[content_type: [{:fields, :field_type}]], :data_template, :state]
        )

      {:error, _} = changeset ->
        changeset
    end
  end

  # Create pipe stages by iterating over the list of content type UUIDs
  # given among the params.
  @spec create_pipe_stages(User.t(), Pipeline.t(), map) :: list
  defp create_pipe_stages(user, pipeline, %{"stages" => stage_data}) when is_list(stage_data) do
    Enum.map(stage_data, fn stage_params -> create_pipe_stage(user, pipeline, stage_params) end)
  end

  defp create_pipe_stages(_, _, _), do: []

  @doc """
  Create a pipe stage.
  """
  @spec create_pipe_stage(User.t(), Pipeline.t(), map) ::
          nil | {:error, Ecto.Changeset.t()} | {:ok, any}
  def create_pipe_stage(
        user,
        pipeline,
        %{
          "content_type_id" => <<_::288>>,
          "data_template_id" => <<_::288>>,
          "state_id" => <<_::288>>
        } = params
      ) do
    params |> get_pipe_stage_params(user) |> do_create_pipe_stages(pipeline)
  end

  def create_pipe_stage(_, _, _), do: nil

  # Get the values for pipe stage creation to create a pipe stage.
  @spec get_pipe_stage_params(map, User.t()) ::
          {ContentType.t(), DataTemplate.t(), State.t(), User.t()}
  defp get_pipe_stage_params(
         %{
           "content_type_id" => c_type_uuid,
           "data_template_id" => d_temp_uuid,
           "state_id" => state_uuid
         },
         user
       ) do
    c_type = get_content_type(user, c_type_uuid)
    d_temp = get_d_template(user, d_temp_uuid)
    state = Enterprise.get_state(user, state_uuid)
    {c_type, d_temp, state, user}
  end

  defp get_pipe_stage_params(_, _), do: nil

  # Create pipe stages
  @spec do_create_pipe_stages(
          {ContentType.t(), DataTemplate.t(), State.t(), User.t()} | nil,
          Pipeline.t()
        ) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_create_pipe_stages(
         {%ContentType{id: c_id}, %DataTemplate{id: d_id}, %State{id: s_id}, %User{id: u_id}},
         pipeline
       ) do
    pipeline
    |> build_assoc(:stages,
      content_type_id: c_id,
      data_template_id: d_id,
      state_id: s_id,
      creator_id: u_id
    )
    |> Stage.changeset()
    |> Repo.insert()
  end

  defp do_create_pipe_stages(_, _), do: nil

  @doc """
  List of all pipelines in the user's organisation.
  """
  @spec pipeline_index(User.t(), map) :: map | nil
  def pipeline_index(%User{organisation_id: org_id}, params) do
    query = from(p in Pipeline, where: p.organisation_id == ^org_id)
    Repo.paginate(query, params)
  end

  def pipeline_index(_, _), do: nil

  @doc """
  Get a pipeline from its UUID and user's organisation.
  """
  @spec get_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def get_pipeline(%User{organisation_id: org_id}, <<_::288>> = p_uuid) do
    query = from(p in Pipeline, where: p.id == ^p_uuid, where: p.organisation_id == ^org_id)
    Repo.one(query)
  end

  def get_pipeline(_, _), do: nil

  @doc """
  Get a pipeline and its details.
  """
  @spec show_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def show_pipeline(current_user, p_uuid) do
    current_user
    |> get_pipeline(p_uuid)
    |> Repo.preload([
      :creator,
      stages: [[content_type: [{:fields, :field_type}]], :data_template, :state]
    ])
  end

  @doc """
  Updates a pipeline.
  """
  @spec pipeline_update(Pipeline.t(), User.t(), map) :: Pipeline.t()
  def pipeline_update(%Pipeline{} = pipeline, %User{id: user_id} = user, params) do
    pipeline
    |> Pipeline.update_changeset(params)
    |> Spur.update(%{actor: "#{user_id}"})
    |> case do
      {:ok, pipeline} ->
        create_pipe_stages(user, pipeline, params)

        Repo.preload(pipeline, [
          :creator,
          stages: [[content_type: [{:fields, :field_type}]], :data_template, :state]
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  def pipeline_update(_, _, _), do: nil

  @doc """
  Delete a pipeline.
  """
  @spec delete_pipeline(Pipeline.t(), User.t()) ::
          {:ok, Pipeline.t()} | {:error, Ecto.Changeset.t()}
  def delete_pipeline(%Pipeline{} = pipeline, %User{id: id}) do
    Spur.delete(pipeline, %{actor: "#{id}", meta: pipeline})
  end

  def delete_pipeline(_, _), do: nil

  @doc """
  Get a pipeline stage from its UUID and user's organisation.
  """
  @spec get_pipe_stage(User.t(), Ecto.UUID.t()) :: Stage.t() | nil
  def get_pipe_stage(%User{organisation_id: org_id}, <<_::288>> = s_uuid) do
    query =
      from(s in Stage,
        join: p in Pipeline,
        where: p.organisation_id == ^org_id and s.pipeline_id == p.id,
        where: s.id == ^s_uuid
      )

    Repo.one(query)
  end

  def get_pipe_stage(_, _), do: nil

  @doc """
  Get all required fields and then update a stage.
  """
  @spec update_pipe_stage(User.t(), Stage.t(), map) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  def update_pipe_stage(%User{} = current_user, %Stage{} = stage, %{
        "content_type_id" => c_uuid,
        "data_template_id" => d_uuid,
        "state_id" => s_uuid
      }) do
    c_type = get_content_type(current_user, c_uuid)
    d_temp = get_d_template(current_user, d_uuid)
    state = Enterprise.get_state(current_user, s_uuid)

    do_update_pipe_stage(current_user, stage, c_type, d_temp, state)
  end

  def update_pipe_stage(_, _, _), do: nil

  # Update a stage.
  @spec do_update_pipe_stage(User.t(), Stage.t(), ContentType.t(), DataTemplate.t(), State.t()) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_update_pipe_stage(user, stage, %ContentType{id: c_id}, %DataTemplate{id: d_id}, %State{
         id: s_id
       }) do
    stage
    |> Stage.update_changeset(%{content_type_id: c_id, data_template_id: d_id, state_id: s_id})
    |> Spur.update(%{actor: "#{user.id}"})
  end

  defp do_update_pipe_stage(_, _, _, _, _), do: nil

  @doc """
  Delete a pipe stage.
  """
  @spec delete_pipe_stage(User.t(), Stage.t()) :: {:ok, Stage.t()}
  def delete_pipe_stage(%User{id: id}, %Stage{} = pipe_stage) do
    %{pipeline: pipeline, content_type: c_type, data_template: d_temp, state: state} =
      Repo.preload(pipe_stage, [:pipeline, :content_type, :data_template, :state])

    meta = %{pipeline: pipeline, content_type: c_type, data_template: d_temp, state: state}

    Spur.delete(pipe_stage, %{actor: "#{id}", meta: meta})
  end

  def delete_pipe_stage(_, _), do: nil

  @doc """
  Preload all datas of a pipe stage excluding pipeline.
  """
  @spec preload_stage_details(Stage.t()) :: Stage.t()
  def preload_stage_details(stage) do
    Repo.preload(stage, [{:content_type, :fields}, :data_template, :state])
  end

  @doc """
  Creates a pipeline trigger history with a user association.

  ## Example
  iex> create_trigger_history(%User{}, %Pipeline{}, %{name: "John Doe"})
  {:ok, %TriggerHistory{}}

  iex> create_trigger_history(%User{}, %Pipeline{}, "meta")
  {:error, Ecto.Changeset}

  iex> create_trigger_history("user", "pipeline", "meta")
  nil
  """
  @spec create_trigger_history(User.t(), Pipeline.t(), map) ::
          {:ok, TriggerHistory.t()} | {:error, Ecto.Changeset.t()} | nil
  def create_trigger_history(%User{id: u_id}, %Pipeline{} = pipeline, data) do
    state = TriggerHistory.states()[:enqued]

    pipeline
    |> build_assoc(:trigger_histories, creator_id: u_id)
    |> TriggerHistory.changeset(%{data: data, state: state})
    |> Repo.insert()
  end

  def create_trigger_history(_, _, _), do: nil

  @doc """
  Get all the triggers under a pipeline.
  """
  @spec get_trigger_histories_of_a_pipeline(Pipeline.t(), map) :: map | nil
  def get_trigger_histories_of_a_pipeline(%Pipeline{id: id}, params) do
    query =
      from(t in TriggerHistory,
        where: t.pipeline_id == ^id,
        preload: [:creator],
        order_by: [desc: t.inserted_at]
      )

    Repo.paginate(query, params)
  end

  def get_trigger_histories_of_a_pipeline(_, _), do: nil

  @doc """
   Get the content type by there id with preloading the data roles
  """

  def get_content_type_roles(id) do
    query = from(c in ContentType, where: c.id == ^id)
    query |> Repo.one() |> Repo.preload(:roles)
  end

  @doc """
    Get the role name by there uuid with preloading the content types
  """

  def get_content_type_under_roles(id) do
    query = from(r in Role, where: r.id == ^id)
    query |> Repo.one() |> Repo.preload(:content_types)
  end

  @doc """
  Get the content type with the id
  """

  def get_content_type(id) do
    query = from(c in ContentType, where: c.id == ^id)
    Repo.one(query)
  end

  @doc """
  create content type role function
  """

  def create_content_type_role(params) do
    %ContentTypeRole{}
    |> ContentTypeRole.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, content_type_role} ->
        Repo.preload(content_type_role, [:role, :content_type])

      {:error, _} = changeset ->
        changeset
    end
  end

  def filter_content_type_title(name, params) do
    query =
      from(ct in ContentType,
        where: ilike(ct.name, ^"%#{name}%"),
        preload: [:fields, :layout, :flow]
      )

    Repo.paginate(query, params)
  end

  # def create_content_type_role(content_id, params) do
  #   content_type = get_content_type(content_id)

  #   Multi.new()
  #   |> Multi.insert(:role, Role.changeset(%Role{}, params))
  #   |> Multi.insert(:content_type_role, fn %{role: role} ->
  #     ContentTypeRole.changeset(%ContentTypeRole{}, %{
  #       content_type_id: content_type.id,
  #       role_id: role.id
  #     })
  #   end)
  #   |> Repo.transaction()
  #   |> case do
  #     {:error, _, changeset, _} ->
  #       {:error, changeset}

  #     {:ok, %{role: _role, content_type_role: content_type_role}} ->
  #       content_type_role
  #   end
  # end

  @doc """
  get role from the respective content type
  """

  def get_role_of_content_type(id, c_id) do
    query = from(r in Role, where: r.id == ^id, join: ct in ContentType, where: ct.id == ^c_id)

    Repo.one(query)
  end

  @doc """
  get the content type from the respective role
  """

  def get_content_type_role(id, role_id) do
    query = from(ct in ContentType, where: ct.id == ^id, join: r in Role, where: r.id == ^role_id)

    Repo.one(query)
  end

  def get_content_type_and_role(id) do
    query = from(ctr in ContentTypeRole, where: ctr.id == ^id)
    Repo.one(query)
  end

  def delete_content_type_role(content_type_role) do
    content_type_role
    |> Repo.delete()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type_role} ->
        content_type_role
    end
  end

  @doc """
  delete the role of the content type
  """

  def delete_role_of_the_content_type(role) do
    role
    |> Repo.delete()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, role} ->
        role
    end
  end

  @doc """
  Returns the list of organisation_field.

  ## Examples

      iex> list_organisation_field()
      [%OrganisationField{}, ...]

  """
  def list_organisation_fields(%{organisation_id: org_id}, params) do
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
  def get_organisation_field(<<_::288>> = id, %{organisation_id: org_id}) do
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
  def create_organisation_field(%{organisation_id: org_id} = current_user, attrs) do
    attrs = Map.put(attrs, "organisation_id", org_id)

    current_user
    |> build_assoc(:organisation_fields)
    |> OrganisationField.changeset(attrs)
    |> Spur.insert()
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
        %{id: u_id, organisation_id: org_id},
        %OrganisationField{} = organisation_field,
        attrs
      ) do
    attrs = Map.put(attrs, "organisation_id", org_id)

    organisation_field
    |> OrganisationField.update_changeset(attrs)
    |> Spur.update(%{actor: u_id})
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
  * `user` - User struct
  * `instance` - Instance struct
  * `params` - map contains the value of editable
  """
  def lock_unlock_instance(%{id: user_id}, %Instance{} = instance, params) do
    instance
    |> Instance.lock_modify_changeset(params)
    |> Spur.update(%{actor: "#{user_id}"})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, instance} ->
        Repo.preload(instance, [
          :creator,
          {:content_type, :layout},
          {:versions, :author},
          {:instance_approval_systems, :approver},
          state: [approval_system: [:post_state, :approver]]
        ])
    end
  end

  def lock_unloack_instance(_, _, _), do: {:error, :not_sufficient}

  @doc """
  Search and list all by key
  """

  @spec instance_index(binary, map) :: map
  def instance_index(%{organisation_id: org_id}, key, params) do
    query =
      from(i in Instance,
        join: ct in ContentType,
        on: i.content_type_id == ct.id,
        where: ct.organisation_id == ^org_id,
        order_by: [desc: i.id],
        preload: [:content_type, :state, :vendor, {:instance_approval_systems, :approver}]
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
  Function to list and paginate instance approval system under  an user
  """
  def instance_approval_system_index(<<_::288>> = user_id, params) do
    query =
      from(ias in InstanceApprovalSystem,
        join: as in ApprovalSystem,
        on: as.id == ias.approval_system_id,
        where: ias.flag == false,
        where: as.approver_id == ^user_id,
        preload: [:instance, :approval_system]
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
        preload: [:instance, :approval_system]
      )

    Repo.paginate(query, params)
  end

  @doc """
  Returns list of changes on a single version
  ## Parameters
  * `instnace` - An instance struct
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

  defp get_previous_version(%{id: instance_id}, %{version_number: version_number}) do
    version_number = version_number - 1
    Repo.get_by(Version, version_number: version_number, content_id: instance_id)
  end

  defp get_previous_version(_, _), do: nil

  def get_collection_form_field(id) do
    case Repo.get_by(CollectionFormField, id: id) do
      %CollectionFormField{} = collection_form_field ->
        collection_form_field

      _ ->
        {:error, :invalid_id, "CollectionFormField"}
    end
  end

  def create_collection_form_field(params) do
    %CollectionFormField{}
    |> CollectionFormField.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %CollectionFormField{} = collection_form} ->
        collection_form

      changeset = {:error, _} ->
        changeset
    end
  end

  def update_collection_form_field(collection_form_field, params) do
    collection_form_field
    |> CollectionFormField.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, collection_form} ->
        collection_form
    end
  end

  def delete_collection_form_field(%CollectionFormField{} = collection_form_field) do
    Repo.delete(collection_form_field)
  end

  def get_collection_form(id) do
    case Repo.get_by(CollectionForm, id: id) do
      %CollectionForm{} = collection_form ->
        collection_form

      _ ->
        {:error, :invalid_id, "CollectionForm"}
    end
  end

  def create_collection_form(params) do
    %CollectionForm{}
    |> CollectionForm.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %CollectionForm{} = collection_form} ->
        Repo.preload(collection_form, [:collection_form_fields])

      changeset = {:error, _} ->
        changeset
    end
  end

  def update_collection_form(collection_form, params) do
    collection_form
    |> CollectionForm.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, collection_form} ->
        collection_form
    end
  end

  def delete_collection_form(%CollectionForm{} = collection_form) do
    Repo.delete(collection_form)
  end

  def list_collection_form(params) do
    query = from(c in CollectionForm, preload: [:collection_form_fields])
    Repo.paginate(query, params)
  end
end
