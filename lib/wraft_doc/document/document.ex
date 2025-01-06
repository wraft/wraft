defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Client.Minio
  alias WraftDoc.Document.Asset
  alias WraftDoc.Document.Block
  alias WraftDoc.Document.BlockTemplate
  alias WraftDoc.Document.CollectionForm
  alias WraftDoc.Document.CollectionFormField
  alias WraftDoc.Document.Comment
  alias WraftDoc.Document.ContentCollaboration
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.ContentTypeField
  alias WraftDoc.Document.ContentTypeRole
  alias WraftDoc.Document.Counter
  alias WraftDoc.Document.CounterParties
  alias WraftDoc.Document.DataTemplate
  alias WraftDoc.Document.Engine
  alias WraftDoc.Document.Field
  alias WraftDoc.Document.FieldType
  alias WraftDoc.Document.Frame
  alias WraftDoc.Document.Instance
  alias WraftDoc.Document.Instance.History
  alias WraftDoc.Document.Instance.Version
  alias WraftDoc.Document.InstanceApprovalSystem
  alias WraftDoc.Document.InstanceTransitionLog
  alias WraftDoc.Document.Layout
  alias WraftDoc.Document.LayoutAsset
  alias WraftDoc.Document.OrganisationField
  alias WraftDoc.Document.Pipeline
  alias WraftDoc.Document.Pipeline.Stage
  alias WraftDoc.Document.Pipeline.TriggerHistory
  alias WraftDoc.Document.Theme
  alias WraftDoc.Document.ThemeAsset
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.StateUser
  alias WraftDoc.Forms
  alias WraftDoc.ProsemirrorToMarkdown
  alias WraftDoc.Repo
  alias WraftDoc.Workers.BulkWorker
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Mailer
  alias WraftDocWeb.Mailer.Email

  @doc """
  Create a layout.
  """
  # TODO - improve tests
  @spec create_layout(User.t(), Engine.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def create_layout(%{current_org_id: org_id} = current_user, engine, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:layouts, engine: engine)
    |> Layout.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, layout} ->
        layout = layout_files_upload(layout, params)
        fetch_and_associcate_assets(layout, current_user, params)
        Repo.preload(layout, [:engine, :creator, :assets, :frame])

      changeset = {:error, _} ->
        changeset
    end
  end

  def create_layout(_, _, _), do: {:error, :fake}

  @doc """
  Upload layout slug/screenshot file.
  """
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

  defp associate_layout_and_asset(%Layout{} = layout, current_user, asset) do
    layout
    |> build_assoc(:layout_assets, asset_id: asset.id, creator: current_user)
    |> LayoutAsset.changeset()
    |> Repo.insert()
  end

  @doc """
  Create a content type.
  """
  # TODO - improve tests
  @spec create_content_type(User.t(), map) :: ContentType.t() | {:error, Ecto.Changeset.t()}
  def create_content_type(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:content_types)
    |> ContentType.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        fetch_and_associate_fields(content_type, params)

        Repo.preload(content_type, [
          :creator,
          :layout,
          :flow,
          {:theme, :assets},
          {:fields, :field_type},
          creator: [:profile]
        ])

      changeset = {:error, _} ->
        changeset
    end
  end

  @spec fetch_and_associate_fields(ContentType.t(), map) :: list
  # Iterate throught the list of field types and associate with the content type
  defp fetch_and_associate_fields(content_type, %{"fields" => fields}) do
    fields
    |> Stream.map(fn x -> create_field_for_content_type(content_type, x) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_fields(_content_type, _params), do: nil

  @spec create_field_for_content_type(ContentType.t(), map) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()} | nil
  defp create_field_for_content_type(
         content_type,
         %{"field_type_id" => field_type_id} = params
       ) do
    field_type_id
    |> get_field_type()
    |> case do
      %FieldType{} = field_type ->
        create_content_type_field(field_type, content_type, params)

      _ ->
        nil
    end
  end

  defp create_field_for_content_type(_content_type, _field), do: nil

  defp create_content_type_field(field_type, content_type, params) do
    params = Map.merge(params, %{"organisation_id" => content_type.organisation_id})

    Multi.new()
    |> Multi.run(:field, fn _, _ -> create_field(field_type, params) end)
    |> Multi.insert(:content_type_field, fn %{field: field} ->
      ContentTypeField.changeset(%ContentTypeField{}, %{
        content_type_id: content_type.id,
        field_id: field.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, step, error, _} ->
        Logger.error("Content type field creation failed in step #{inspect(step)}", error: error)
        :error
    end
  end

  @doc """
  Creates a field.

  ## Example

  iex> create_field(%FieldType{}, %{name: "name"})
  {:ok, %Field{}}

  iex> create_field(%FieldType{}, %{})
  {:error, %Ecto.Changeset{}}
  """
  def create_field(field_type, params) do
    field_type
    |> build_assoc(:fields)
    |> Field.changeset(params)
    |> Repo.insert()
  end

  # TODO write test
  @doc """
    Update a field
  """
  @spec update_field(Field.t(), map) :: Field.t() | nil
  def update_field(%Field{} = field, params) do
    field
    |> Field.update_changeset(params)
    |> Repo.update()
  end

  # TODO write test
  @doc """
    Get field
  """
  @spec get_field(Ecto.UUID.t()) :: Field.t() | nil
  def get_field(<<_::288>> = field_id) do
    Repo.get(Field, field_id)
  end

  def get_field(_), do: nil

  @doc """
  List all engines.

  ## Example

    iex> engines_list(%{})
    list of available engines
  """
  @spec engines_list(map) :: map
  def engines_list(params) do
    Repo.paginate(Engine, params)
  end

  @doc """
  List all layouts.
  """
  # TODO - improve tests
  @spec layout_index(User.t(), map) :: map
  def layout_index(%{current_org_id: org_id}, params) do
    query =
      from(l in Layout,
        where: l.organisation_id == ^org_id,
        where: ^layout_index_filter_by_name(params),
        order_by: ^layout_index_sort(params),
        preload: [:engine, :assets, :frame]
      )

    Repo.paginate(query, params)
  end

  defp layout_index_filter_by_name(%{"name" => name} = _params),
    do: dynamic([l], ilike(l.name, ^"%#{name}%"))

  defp layout_index_filter_by_name(_), do: true

  defp layout_index_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([l], l.name)]

  defp layout_index_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([l], l.name)]

  defp layout_index_sort(%{"sort" => "inserted_at"} = _params),
    do: [asc: dynamic([l], l.inserted_at)]

  defp layout_index_sort(%{"sort" => "inserted_at_desc"} = _params),
    do: [desc: dynamic([l], l.inserted_at)]

  defp layout_index_sort(_), do: []

  @doc """
  Show a layout.
  """
  @spec show_layout(binary, User.t()) :: %Layout{engine: Engine.t(), creator: User.t()}
  def show_layout(id, user) do
    with %Layout{} = layout <-
           get_layout(id, user) do
      Repo.preload(layout, [:engine, :creator, :assets, :frame])
    end
  end

  @doc """
  Get a layout from its UUID.
  """
  @spec get_layout(binary, User.t()) :: Layout.t()
  def get_layout(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Layout, id: id, organisation_id: org_id) do
      %Layout{} = layout ->
        layout

      _ ->
        {:error, :invalid_id, "Layout"}
    end
  end

  def get_layout(_, %{current_org_id: _}), do: {:error, :invalid_id, "Layout"}
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
        on: la.layout_id == l.id,
        join: a in Asset,
        on: la.asset_id == a.id,
        where: l.id == ^l_id and a.id == ^a_id
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

  def update_layout(layout, current_user, params) do
    layout
    |> Layout.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, layout} ->
        fetch_and_associcate_assets(layout, current_user, params)
        Repo.preload(layout, [:engine, :creator, :assets, :frame])
    end
  end

  @doc """
  Delete a layout.
  """
  # TODO - improve tests
  @spec delete_layout(Layout.t()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def delete_layout(layout) do
    layout
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :content_types,
      message:
        "Cannot delete the layout. Some Content types depend on this layout. Update those content types and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Delete a layout asset.
  """
  # TODO - improve tests
  @spec delete_layout_asset(LayoutAsset.t()) ::
          {:ok, LayoutAsset.t()} | {:error, Ecto.Changeset.t()}
  def delete_layout_asset(layout_asset), do: Repo.delete(layout_asset)

  @doc """
  List all content types.
  """
  @spec content_type_index(User.t(), map) :: map
  def content_type_index(%{current_org_id: org_id}, params) do
    ContentType
    |> where([ct], ct.organisation_id == ^org_id)
    |> where(^content_type_filter_by_name(params))
    |> where(^content_type_filter_by_prefix(params))
    |> order_by([ct], ^content_type_sort(params))
    |> preload([:layout, :flow, {:theme, :assets}, {:fields, :field_type}, creator: [:profile]])
    |> Repo.paginate(params)
  end

  defp content_type_filter_by_name(%{"name" => name} = _params),
    do: dynamic([ct], ilike(ct.name, ^"%#{name}%"))

  defp content_type_filter_by_name(_), do: true

  defp content_type_filter_by_prefix(%{"prefix" => prefix} = _params),
    do: dynamic([ct], ilike(ct.prefix, ^"%#{prefix}%"))

  defp content_type_filter_by_prefix(_), do: true

  defp content_type_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([ct], ct.name)]

  defp content_type_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([ct], ct.name)]

  defp content_type_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([ct], ct.inserted_at)]

  defp content_type_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([ct], ct.inserted_at)]

  defp content_type_sort(_), do: []

  @doc """
  Show a content type.
  """
  # TODO - improve tests
  @spec show_content_type(User.t(), Ecto.UUID.t()) ::
          %ContentType{layout: Layout.t(), creator: User.t()} | nil
  def show_content_type(user, id) do
    with %ContentType{} = content_type <- get_content_type(user, id) do
      Repo.preload(content_type, [
        :layout,
        :creator,
        {:theme, :assets},
        [{:fields, :field_type}, {:flow, :states}]
      ])
    end
  end

  @doc """
  Get a content type from its UUID and user's organisation ID.
  """
  @spec get_content_type(User.t(), Ecto.UUID.t()) ::
          ContentType.t() | {:error, :invalid_id, String.t()}
  def get_content_type(%User{current_org_id: org_id}, <<_::288>> = id) do
    ContentType
    |> Repo.get_by(id: id, organisation_id: org_id)
    |> case do
      %ContentType{} = content_type ->
        Repo.preload(content_type, [
          :layout,
          :creator,
          {:theme, :assets},
          [{:flow, :states}, {:fields, :field_type}]
        ])

      _ ->
        {:error, :invalid_id, "ContentType"}
    end
  end

  def get_content_type(%User{current_org_id: _org_id}, _),
    do: {:error, :invalid_id, "ContentType"}

  def get_content_type(_, _), do: {:error, :fake}

  @doc """
  Get a content type from its ID. Also fetches all its related datas.
  """
  # TODO - improve tests
  @spec get_content_type_from_id(integer()) :: %ContentType{layout: %Layout{}, creator: %User{}}
  def get_content_type_from_id(id) do
    ContentType
    |> Repo.get(id)
    |> Repo.preload([:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
  end

  @doc """
  Get a content type field from its UUID.
  """
  @spec get_content_type_field(binary, User.t()) :: ContentTypeField.t()
  def get_content_type_field(<<_::288>> = id, %{current_org_id: org_id}) do
    query =
      from(cf in ContentTypeField,
        where: cf.id == ^id,
        join: c in ContentType,
        on: c.id == cf.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %ContentTypeField{} = content_type_field -> content_type_field
      _ -> {:error, :invalid_id, "ContentTypeField"}
    end
  end

  def get_content_type_field(<<_::288>>, _), do: {:error, :invalid_id, "ContentTypeField"}
  def get_content_type_field(_, %{current_org_id: _}), do: {:error, :fake}

  @doc """
    Get Content Type field from content type id and field id
  """
  @spec get_content_type_field(map) :: ContentTypeField.t() | nil
  def get_content_type_field(%{"content_type_id" => content_type_id, "field_id" => field_id}),
    do: Repo.get_by(ContentTypeField, content_type_id: content_type_id, field_id: field_id)

  @doc """
  Update a content type.
  """
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

  def update_content_type(content_type, _user, params) do
    content_type
    |> ContentType.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type} ->
        fetch_and_associate_fields(content_type, params)

        Repo.preload(content_type, [
          :layout,
          :creator,
          {:theme, :assets},
          [{:flow, :states}, {:fields, :field_type}]
        ])
    end
  end

  @doc """
  Delete a content type.
  """
  @spec delete_content_type(ContentType.t()) ::
          {:ok, ContentType.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type(content_type) do
    content_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the content type. There are many contents under this content type. Delete those contents and try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Delete a content type field.
  """
  @spec delete_content_type_field(ContentTypeField.t()) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type_field(content_type_field) do
    %ContentTypeField{field: field} = Repo.preload(content_type_field, :field)
    Repo.delete(field)
    Repo.delete(content_type_field)
    :ok
  end

  defp create_initial_version(%{id: author_id}, instance) do
    params = %{
      "version_number" => 1,
      "naration" => "Initial version",
      "raw" => instance.raw,
      "serialized" => instance.serialized,
      "author_id" => author_id
    }

    Logger.info("Creating initial version...")

    %Version{}
    |> Version.changeset(params)
    |> Repo.insert!()

    Logger.info("Initial version generated")
    {:ok, "ok"}
  end

  defp create_initial_version(_, _), do: {:error, :invalid}

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
        Repo.preload(content, [
          :content_type,
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
  @spec create_instance(User.t(), ContentType.t(), map) ::
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
  @spec instance_index_of_an_organisation(User.t(), map) :: map
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
  @spec instance_index(binary, map) :: map
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

  @spec instance_index(map(), map()) :: map
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
  @spec get_instance(binary, User.t()) :: Instance.t() | nil
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
  @spec show_instance(binary, User.t()) ::
          %Instance{creator: User.t(), content_type: ContentType.t(), state: State.t()} | nil
  def show_instance(instance_id, user) do
    with %Instance{} = instance <- get_instance(instance_id, user) do
      instance
      |> Repo.preload([
        {:creator, :profile},
        {:content_type, :layout},
        {:versions, :author},
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

  def show_instance_guest(document_id) do
    Repo.get(Instance, document_id)
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
          versions: versions
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
          Path.join(instance_dir_path, versioned_file_name(versions, instance_id, :current))

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
  @spec update_instance(Instance.t(), map) ::
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
        |> Repo.insert()

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

  defp instance_updated?(new_instance) do
    new_instance
    |> get_last_version()
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
  Create a theme.
  """
  @spec create_theme(User.t(), map) :: {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def create_theme(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    current_user
    |> build_assoc(:themes)
    |> Theme.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, theme} ->
        theme_preview_file_upload(theme, params)
        fetch_and_associcate_assets_with_theme(theme, current_user, params)

        Repo.preload(theme, [:assets])

      {:error, _} = changeset ->
        changeset
    end
  end

  # Get all the assets from their UUIDs and associate them with the given theme.
  defp fetch_and_associcate_assets_with_theme(theme, current_user, %{"assets" => assets}) do
    (assets || "")
    |> String.split(",")
    |> Stream.map(fn asset -> get_asset(asset, current_user) end)
    |> Stream.map(fn asset -> associate_theme_and_asset(theme, asset) end)
    |> Enum.to_list()
  end

  defp fetch_and_associcate_assets_with_theme(_theme, _current_user, _params), do: []

  # Associate the asset with the given theme, ie; insert a ThemeAsset entry.
  defp associate_theme_and_asset(theme, %Asset{} = asset) do
    %ThemeAsset{}
    |> ThemeAsset.changeset(%{theme_id: theme.id, asset_id: asset.id})
    |> Repo.insert()
  end

  defp associate_theme_and_asset(_theme, _asset), do: nil

  @doc """
  Upload theme preview file.
  """
  @spec theme_preview_file_upload(Theme.t(), map) ::
          {:ok, %Theme{}} | {:error, Ecto.Changeset.t()}
  def theme_preview_file_upload(theme, %{"preview_file" => _} = params) do
    theme |> Theme.file_changeset(params) |> Repo.update()
  end

  def theme_preview_file_upload(theme, _params) do
    {:ok, theme}
  end

  @doc """
  Index of themes inside current user's organisation.
  """
  @spec theme_index(User.t(), map) :: map
  def theme_index(%User{current_org_id: org_id}, params) do
    Theme
    |> where([t], t.organisation_id == ^org_id)
    |> where(^theme_filter_by_name(params))
    |> order_by(^theme_sort(params))
    |> preload(:assets)
    |> Repo.paginate(params)
  end

  defp theme_filter_by_name(%{"name" => name} = _params),
    do: dynamic([t], ilike(t.name, ^"%#{name}%"))

  defp theme_filter_by_name(_), do: true

  defp theme_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([t], t.name)]

  defp theme_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([t], t.name)]

  defp theme_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([t], t.inserted_at)]

  defp theme_sort(%{"sort" => "inserted_at_desc"}), do: [desc: dynamic([t], t.inserted_at)]

  defp theme_sort(_), do: []

  @doc """
  Get a theme from its UUID.
  """
  # TODO - improve test
  @spec get_theme(binary, User.t()) :: Theme.t() | nil
  def get_theme(theme_uuid, %{current_org_id: org_id}) do
    Theme
    |> Repo.get_by(id: theme_uuid, organisation_id: org_id)
    |> Repo.preload(:assets)
  end

  def get_theme(theme_id, org_id) do
    Logger.info(
      "Theme not found for theme_id #{inspect(theme_id)} - organisation_id #{inspect(org_id)}"
    )

    nil
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
  @spec update_theme(Theme.t(), User.t(), map()) ::
          {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def update_theme(theme, current_user, params) do
    theme
    |> Theme.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, theme} ->
        theme_preview_file_upload(theme, params)
        fetch_and_associcate_assets_with_theme(theme, current_user, params)

        Repo.preload(theme, [:assets])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a theme.
  """
  @spec delete_theme(Theme.t()) :: {:ok, Theme.t()}
  def delete_theme(%{organisation_id: org_id} = theme) do
    asset_query =
      from(asset in Asset,
        join: theme_asset in ThemeAsset,
        on: asset.id == theme_asset.asset_id and theme_asset.theme_id == ^theme.id,
        select: asset.id
      )

    theme_asset_query = from(ta in ThemeAsset, where: ta.theme_id == ^theme.id)

    # Delete the theme preview file
    Minio.delete_file("organisations/#{org_id}/theme/theme_preview/#{theme.id}")

    # Deletes the asset files
    asset_query
    |> Repo.all()
    |> Enum.each(&Minio.delete_file("organisations/#{org_id}/assets/#{&1}"))

    Repo.delete_all(asset_query)
    Repo.delete_all(theme_asset_query)
    Repo.delete(theme)
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
    |> Repo.insert()
  end

  def create_data_template(%User{}, _, _), do: {:error, :invalid_id, "ContentType"}
  def create_data_template(_, _, _), do: {:error, :fake}

  @doc """
  List all data templates under a content types.
  """
  @spec data_template_index(binary, map) :: map
  def data_template_index(<<_::288>> = c_type_id, params) do
    DataTemplate
    |> join(:inner, [dt], ct in ContentType,
      on: ct.id == dt.content_type_id and ct.id == ^c_type_id
    )
    |> where(^data_template_filter_by_title(params))
    |> order_by(^data_template_sort(params))
    |> preload([:content_type])
    |> Repo.paginate(params)
  end

  @doc """
  List all data templates under current user's organisation.
  """
  @spec data_templates_index_of_an_organisation(User.t(), map) :: map
  def data_templates_index_of_an_organisation(%{current_org_id: org_id}, params) do
    DataTemplate
    |> join(:inner, [dt], ct in ContentType, on: ct.id == dt.content_type_id)
    |> where([dt, ct], ct.organisation_id == ^org_id)
    |> where(^data_template_filter_by_title(params))
    |> order_by(^data_template_sort(params))
    |> preload(:content_type)
    |> Repo.paginate(params)
  end

  def data_templates_index_of_an_organisation(_, _), do: {:error, :fake}

  defp data_template_filter_by_title(%{"title" => title} = _params),
    do: dynamic([dt], ilike(dt.title, ^"%#{title}%"))

  defp data_template_filter_by_title(_), do: true

  defp data_template_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([dt], dt.inserted_at)]

  defp data_template_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([dt], dt.inserted_at)]

  defp data_template_sort(%{"sort" => "updated_at"} = _params),
    do: [asc: dynamic([dt], dt.updated_at)]

  defp data_template_sort(%{"sort" => "updated_at_desc"}),
    do: [desc: dynamic([dt], dt.updated_at)]

  defp data_template_sort(_), do: []

  @doc """
  Get a data template from its uuid and organisation ID of user.
  """
  # TODO - imprvove tests
  @spec get_d_template(User.t(), Ecto.UUID.t()) :: DataTemplat.t() | nil
  def get_d_template(%User{current_org_id: org_id}, <<_::288>> = d_temp_id) do
    query =
      from(d in DataTemplate,
        where: d.id == ^d_temp_id,
        join: c in ContentType,
        on: c.id == d.content_type_id and c.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %DataTemplate{} = data_template -> data_template
      _ -> {:error, :invalid_id, "DataTemplate"}
    end
  end

  def get_d_template(%{current_org_id: _}, _), do: {:error, :invalid_id, "DataTemplate"}
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
      Repo.preload(data_template, [:creator, [content_type: [{:fields, :field_type}]]])
    end
  end

  @doc """
  Update a data template
  """
  # TODO - imprvove tests
  @spec update_data_template(DataTemplate.t(), map) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()}
          | {:error, Ecto.Changeset.t()}
  def update_data_template(d_temp, params) do
    d_temp
    |> DataTemplate.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, d_temp} ->
        Repo.preload(d_temp, [:creator, [content_type: [{:fields, :field_type}]]])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a data template
  """
  # TODO - imprvove tests
  @spec delete_data_template(DataTemplate.t()) :: {:ok, DataTemplate.t()}
  def delete_data_template(d_temp), do: Repo.delete(d_temp)

  @doc """
  Create an asset.
  """
  # TODO - imprvove tests
  @spec create_asset(User.t(), map) :: {:ok, Asset.t()}
  def create_asset(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id})

    Multi.new()
    |> Multi.insert(:asset, current_user |> build_assoc(:assets) |> Asset.changeset(params))
    |> Multi.update(:asset_file_upload, &Asset.file_changeset(&1.asset, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{asset_file_upload: asset}} -> {:ok, asset}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def create_asset(_, _), do: {:error, :fake}

  @doc """
  Index of all assets in an organisation.
  """
  # TODO - improve tests
  @spec asset_index(integer, map) :: map
  def asset_index(%{current_org_id: organisation_id}, params) do
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
  def get_asset(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Asset, id: id, organisation_id: org_id) do
      %Asset{} = asset -> asset
      _ -> {:error, :invalid_id}
    end
  end

  def get_asset(<<_::288>>, _), do: {:error, :fake}
  def get_asset(_, %{current_org_id: _}), do: {:error, :invalid_id}

  @doc """
  Update an asset.
  """
  # TODO - improve tests
  # file uploading is throwing errors, in tests
  @spec update_asset(Asset.t(), map) :: {:ok, Asset.t()} | {:error, Ecto.Changset.t()}
  def update_asset(asset, params) do
    asset |> Asset.update_changeset(params) |> Repo.update()
  end

  @doc """
  Delete an asset.
  """
  @spec delete_asset(Asset.t()) :: {:ok, Asset.t()}
  def delete_asset(asset) do
    # Delete the uploaded file
    Repo.delete(asset)
  end

  @doc """
  Preload assets of a layout.
  """
  @spec preload_asset(Layout.t()) :: Layout.t()
  def preload_asset(%Layout{} = layout) do
    Repo.preload(layout, [:assets])
  end

  def preload_asset(_), do: {:error, :not_sufficient}

  @doc """
  Build a PDF document.
  """
  # TODO  - Write Test
  # TODO - Dont need to pass layout as an argument, we can just preload it
  @spec build_doc(Instance.t(), Layout.t()) :: {any, integer}
  def build_doc(
        %Instance{instance_id: instance_id, content_type: content_type, versions: versions} =
          instance,
        %Layout{organisation_id: org_id} = layout
      ) do
    content_type = Repo.preload(content_type, [:fields, :theme])
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    base_content_dir = Path.join(File.cwd!(), instance_dir_path)
    File.mkdir_p(base_content_dir)

    # Load all the assets corresponding with the given theme
    theme = Repo.preload(content_type.theme, [:assets])

    file_path =
      layout
      |> Repo.preload([:frame])
      |> download_slug_file()

    System.cmd("cp", ["-a", file_path, base_content_dir])

    # Generate QR code for the file
    task = Task.async(fn -> generate_qr(instance, base_content_dir) end)

    instance_updated? = instance_updated?(instance)
    # Move old builds to the history folder
    current_instance_file = versioned_file_name(versions, instance_id, :current)

    Task.start(fn ->
      move_old_builds(instance_dir_path, current_instance_file, instance_updated?)
    end)

    theme = get_theme_details(theme, base_content_dir)

    header =
      Enum.reduce(content_type.fields, "--- \n", fn x, acc ->
        find_header_values(x, instance.serialized, acc)
      end)

    content =
      prepare_markdown(
        instance,
        Repo.preload(layout, [:organisation, :frame]),
        header,
        base_content_dir,
        theme,
        task
      )

    File.write("#{base_content_dir}/content.md", content)
    pdf_file = pdf_file_path(instance, instance_dir_path, instance_updated?)

    pandoc_commands = prepare_pandoc_cmds(pdf_file, base_content_dir)

    "pandoc"
    |> System.cmd(pandoc_commands, stderr_to_stdout: true)
    |> upload_file_and_delete_local_copy(base_content_dir, pdf_file)
  end

  defp download_slug_file(%Layout{frame: nil, slug: slug}),
    do: :wraft_doc |> :code.priv_dir() |> Path.join("slugs/#{slug}/.")

  defp download_slug_file(%Layout{
         frame: %Frame{id: frame_id, name: name},
         organisation_id: organisation_id
       }) do
    :wraft_doc
    |> :code.priv_dir()
    |> Path.join("slugs/organisation/#{organisation_id}/#{name}/.")
    |> File.exists?()
    |> case do
      true ->
        :wraft_doc
        |> :code.priv_dir()
        |> Path.join("slugs/organisation/#{organisation_id}/#{name}/.")

      false ->
        slugs_dir =
          :wraft_doc
          |> :code.priv_dir()
          |> Path.join("slugs/organisation/#{organisation_id}/#{name}/.")

        File.mkdir_p!(slugs_dir)

        template_path = Path.join(slugs_dir, "template.tex")

        "organisations/#{organisation_id}/frames/#{frame_id}"
        |> Minio.download()
        |> then(&File.write!(template_path, &1))

        slugs_dir
    end
  end

  defp pdf_file_path(
         %Instance{instance_id: instance_id, versions: versions},
         instance_dir_path,
         true
       ) do
    versions
    |> versioned_file_name(instance_id, :next)
    |> then(&Path.join(instance_dir_path, &1))
  end

  defp pdf_file_path(
         %Instance{instance_id: instance_id, versions: versions},
         instance_dir_path,
         false
       ) do
    versions
    |> versioned_file_name(instance_id, :current)
    |> then(&Path.join(instance_dir_path, &1))
  end

  defp versioned_file_name(versions, instance_id, :current),
    do: instance_id <> "-v" <> to_string(length(versions)) <> ".pdf"

  defp versioned_file_name(versions, instance_id, :next),
    do: instance_id <> "-v" <> to_string(length(versions) + 1) <> ".pdf"

  defp prepare_markdown(
         %{id: instance_id, creator: %User{name: name, email: email}} = instance,
         %Layout{organisation: %Organisation{name: organisation_name}} = layout,
         header,
         mkdir,
         theme,
         task
       ) do
    header =
      Enum.reduce(layout.assets, header, fn x, acc ->
        find_asset_header_values(x, acc, layout, instance)
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
      |> concat_strings("mainfontoptions:\n")
      |> font_option_header(theme.font_options)
      |> concat_strings("body_color: #{theme.body_color}\n")
      |> concat_strings("primary_color: #{theme.primary_color}\n")
      |> concat_strings("secondary_color: #{theme.secondary_color}\n")
      |> concat_strings("typescale: #{theme.typescale}\n")
      |> concat_strings("--- \n")

    """
    #{header}
    #{instance.raw}
    """
  end

  @spec get_theme_details(Theme.t(), String.t()) :: map()
  def get_theme_details(theme, mkdir) do
    [%{file: %{file_name: file_name}} | _] = theme.assets
    [font_name, _, file_type] = String.split(file_name, ~r/[-.]/)

    %{
      body_color: theme.body_color,
      primary_color: theme.primary_color,
      secondary_color: theme.secondary_color,
      typescale: Jason.encode!(theme.typescale),
      font_name: "#{font_name}-Regular.#{file_type}",
      font_options: font_options(theme, mkdir)
    }
  end

  defp font_options(%Theme{organisation_id: org_id} = theme, mkdir) do
    theme.assets
    |> Stream.map(fn asset ->
      file_name = asset.file.file_name
      binary = Minio.download("organisations/#{org_id}/assets/#{asset.id}/#{file_name}")

      mkdir
      |> Path.join("fonts")
      |> File.mkdir_p!()

      asset_file_path = Path.join(mkdir, "fonts/#{file_name}")
      File.write!(asset_file_path, binary)

      [_, font_type, _] = String.split(file_name, ~r/[-.]/)

      case Enum.member?(["Bold", "Italic", "BoldItalic"], font_type) do
        true -> "#{font_type}Font=#{file_name}"
        false -> ""
      end
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp font_option_header(header, font_options) do
    Enum.reduce(font_options, header, fn font_option, acc ->
      concat_strings(acc, "- #{font_option}\n")
    end)
  end

  defp prepare_pandoc_cmds(pdf_file, base_content_dir) do
    [
      "#{base_content_dir}/content.md",
      "--template=#{base_content_dir}/template.tex",
      "--pdf-engine=#{System.get_env("XELATEX_PATH")}",
      "-o",
      pdf_file
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
        pandoc_response

      _ ->
        File.rm(pdf_file)
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

  # Find the header values for the content.md file from the assets of the layout used.
  @spec find_asset_header_values(Asset.t(), String.t(), String.t(), Instance.t()) :: String.t()
  defp find_asset_header_values(
         %Asset{name: name, file: file, organisation_id: org_id} = asset,
         acc,
         %Layout{frame: frame, slug: slug},
         %Instance{
           instance_id: instance_id
         }
       ) do
    binary = Minio.download("organisations/#{org_id}/assets/#{asset.id}/#{file.file_name}")

    asset_file_path =
      Path.join(File.cwd!(), "organisations/#{org_id}/contents/#{instance_id}/#{file.file_name}")

    File.write!(asset_file_path, binary)

    if frame != nil || slug == "pletter" do
      concat_strings(acc, "letterhead: #{asset_file_path} \n")
    else
      concat_strings(acc, "#{name}: #{asset_file_path} \n")
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
  defp concat_strings(string1, string2) do
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
  Create a Block
  """
  @spec create_block(User.t(), map) :: Block.t()
  def create_block(%{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id, "creator_id" => current_user.id})

    Multi.new()
    |> Multi.insert(:block, Block.changeset(%Block{}, params))
    |> Multi.update(:block_input, &Block.block_input_changeset(&1.block, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{block_input: block}} -> block
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def create_block(_, _), do: {:error, :fake}

  @doc """
  Get a block by id
  """
  @spec get_block(Ecto.UUID.t(), User.t()) :: Block.t()
  def get_block(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Block, id: id, organisation_id: org_id) do
      %Block{} = block -> block
      _ -> {:error, :invalid_id, "Block"}
    end
  end

  def get_block(<<_::288>>, _), do: {:error, :fake}
  def get_block(_, %{current_org_id: _}), do: {:error, :invalid_id, "Block"}

  @doc """
  Update a block
  """
  def update_block(%Block{} = block, params) do
    block
    |> Block.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, block} ->
        block

      {:error, _} = changeset ->
        changeset
    end
  end

  def update_block(_, _), do: {:error, :fake}

  @doc """
  Delete a block
  """
  def delete_block(%Block{} = block) do
    Repo.delete(block)
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
  Create a field type
  """
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
  @spec field_type_index() :: [FieldType.t()]
  def field_type_index, do: Repo.all(FieldType, order_by: [desc: :id])

  @doc """
  Get a field type.
  """
  @spec get_field_type(binary) :: FieldType.t()
  def get_field_type(<<_::288>> = field_type_id) do
    case Repo.get(FieldType, field_type_id) do
      %FieldType{} = field_type -> field_type
      _ -> {:error, :invalid_id, "FieldType"}
    end
  end

  def get_field_type(_), do: {:error, :fake}

  @spec get_field_type_by_name(String.t()) :: FieldType.t() | nil
  def get_field_type_by_name(field_type_name) do
    case Repo.get_by(FieldType, name: field_type_name) do
      %FieldType{} = field_type -> field_type
      _ -> nil
    end
  end

  @doc """
  Update a field type
  """
  @spec update_field_type(FieldType.t(), map) :: FieldType.t() | {:error, Ecto.Changeset.t()}
  def update_field_type(field_type, params) do
    field_type
    |> FieldType.changeset(params)
    |> Repo.update()
  end

  @doc """
  Deleta a field type
  """
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
  # TODO - improve tests
  @spec create_pipeline_job(TriggerHistory.t(), DateTime.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def create_pipeline_job(%TriggerHistory{} = trigger_history, scheduled_at) do
    create_bulk_job(trigger_history, scheduled_at, ["pipeline_job"])
  end

  def create_pipeline_job(%TriggerHistory{} = trigger_history) do
    create_bulk_job(trigger_history, nil, ["pipeline_job"])
  end

  def create_pipeline_job(_), do: nil

  defp create_bulk_job(args, scheduled_at \\ nil, tags \\ []) do
    args
    |> BulkWorker.new(tags: tags, scheduled_at: scheduled_at)
    |> Oban.insert()
  end

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
  def create_block_template(%{current_org_id: org_id} = current_user, params) do
    current_user
    |> build_assoc(:block_templates, organisation_id: org_id)
    |> BlockTemplate.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, block_template} ->
        Repo.preload(block_template, [{:creator, :profile}])

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_block_template(_, _), do: {:error, :fake}

  @doc """
  Get a block template by its uuid
  """
  @spec get_block_template(Ecto.UUID.t(), BlockTemplate.t()) :: BlockTemplate.t()
  def get_block_template(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(BlockTemplate, id: id, organisation_id: org_id) do
      %BlockTemplate{} = block_template -> Repo.preload(block_template, [{:creator, :profile}])
      _ -> {:error, :invalid_id, "BlockTemplate"}
    end
  end

  def get_block_template(<<_::288>>, _), do: {:error, :invalid_id, "BlockTemplate"}
  def get_block_template(_, %{current_org_id: _org_id}), do: {:error, :fake}
  def get_block_template(_, _), do: {:error, :invalid_id, "BlockTemplate"}

  @doc """
  Updates a block template
  """
  @spec update_block_template(BlockTemplate.t(), map) :: BlockTemplate.t()
  def update_block_template(block_template, params) do
    block_template
    |> BlockTemplate.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, block_template} ->
        Repo.preload(block_template, [{:creator, :profile}])
    end
  end

  @doc """
  Delete a block template
  """
  @spec delete_block_template(BlockTemplate.t()) :: {:ok, BlockTemplate.t()}
  def delete_block_template(%BlockTemplate{} = block_template), do: Repo.delete(block_template)

  def delete_block_template(_), do: {:error, :fake}

  @doc """
  Index of a block template by organisation
  """
  @spec block_template_index(User.t(), map) :: List.t()
  def block_template_index(%{current_org_id: org_id}, params) do
    BlockTemplate
    |> where([bt], bt.organisation_id == ^org_id)
    |> preload([bt], creator: [:profile])
    |> order_by([bt], desc: bt.id)
    |> Repo.paginate(params)
  end

  @doc """
  Create a comment
  """
  # TODO - improve tests
  def create_comment(%{current_org_id: <<_::288>> = org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)
    insert_comment(current_user, params)
  end

  def create_comment(%{current_org_id: nil} = current_user, params),
    do: insert_comment(current_user, params)

  def create_comment(_, _), do: {:error, :fake}

  # Private
  defp insert_comment(current_user, params) do
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

  @doc """
  Get a comment by uuid.
  """
  # TODO - improve tests
  @spec get_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def get_comment(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Comment, id: id, organisation_id: org_id) do
      %Comment{} = comment -> comment
      _ -> {:error, :invalid_id, "Comment"}
    end
  end

  def get_comment(<<_::288>>, _), do: {:error, :fake}
  def get_comment(_, %{current_org_id: _}), do: {:error, :invalid_id, "Comment"}
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
  def comment_index(%{current_org_id: org_id}, %{"master_id" => master_id} = params) do
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

  def comment_index(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_index(_, %{"master_id" => _}), do: {:error, :fake}
  def comment_index(_, _), do: {:error, :invalid_data}

  @doc """
   Replies under a comment
  """
  # TODO - improve tests
  @spec comment_replies(%{current_org_id: any}, map) :: Scrivener.Page.t()
  def comment_replies(
        %{current_org_id: org_id} = user,
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
  def comment_replies(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_replies(_, _), do: {:error, :invalid_data}

  @doc """
  Create a pipeline.
  """
  @spec create_pipeline(User.t(), map) :: Pipeline.t() | {:error, Ecto.Changeset.t()}
  def create_pipeline(%{current_org_id: org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)

    current_user
    |> build_assoc(:pipelines)
    |> Pipeline.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, pipeline} ->
        create_pipe_stages(current_user, pipeline, params)

        Repo.preload(pipeline,
          stages: [
            [content_type: [{:fields, :field_type}]],
            :data_template,
            :state,
            :form_mapping
          ]
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
  # TOOD update the tests as state id is removed from the params.
  @spec create_pipe_stage(User.t(), Pipeline.t(), map) ::
          nil | {:error, Ecto.Changeset.t()} | {:ok, any}
  def create_pipe_stage(
        user,
        pipeline,
        %{
          "content_type_id" => <<_::288>>,
          "data_template_id" => <<_::288>>
        } = params
      ) do
    params
    |> get_pipe_stage_params(user)
    |> do_create_pipe_stages(pipeline)
  end

  def create_pipe_stage(_, _, _), do: nil

  # Get the values for pipe stage creation to create a pipe stage.
  # TODO update tests as state id is removed from the params.
  @spec get_pipe_stage_params(map, User.t()) ::
          {ContentType.t(), DataTemplate.t(), State.t(), User.t()}
  defp get_pipe_stage_params(
         %{
           "content_type_id" => c_type_uuid,
           "data_template_id" => d_temp_uuid
         },
         user
       ) do
    c_type = get_content_type(user, c_type_uuid)
    d_temp = get_d_template(user, d_temp_uuid)
    {c_type, d_temp, user}
  end

  defp get_pipe_stage_params(_, _), do: nil

  # Create pipe stages
  # TODO update tests as state id is removed from the params.
  @spec do_create_pipe_stages(
          {ContentType.t(), DataTemplate.t(), User.t()} | nil,
          Pipeline.t()
        ) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_create_pipe_stages(
         {%ContentType{id: c_id}, %DataTemplate{id: d_id}, %User{id: u_id}},
         pipeline
       ) do
    pipeline
    |> build_assoc(:stages,
      content_type_id: c_id,
      data_template_id: d_id,
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
  def pipeline_index(%User{current_org_id: org_id}, params) do
    Pipeline
    |> where([p], p.organisation_id == ^org_id)
    |> where(^pipeline_filter_by_name(params))
    |> order_by(^pipeline_sort(params))
    |> join(:left, [p], ps in assoc(p, :stages))
    |> select_merge([p, ps], %{stages_count: count(ps.id)})
    |> group_by([p], p.id)
    |> Repo.paginate(params)
  end

  def pipeline_index(_, _), do: nil

  defp pipeline_filter_by_name(%{"name" => name} = _params),
    do: dynamic([p], ilike(p.name, ^"%#{name}%"))

  defp pipeline_filter_by_name(_), do: true

  defp pipeline_sort(%{"sort" => "name_desc"} = _params), do: [desc: dynamic([p], p.name)]

  defp pipeline_sort(%{"sort" => "name"} = _params), do: [asc: dynamic([p], p.name)]

  defp pipeline_sort(%{"sort" => "inserted_at"}), do: [asc: dynamic([p], p.inserted_at)]

  defp pipeline_sort(%{"sort" => "inserted_at_desc"}),
    do: [desc: dynamic([p], p.inserted_at)]

  defp pipeline_sort(_), do: []

  @doc """
  Get a pipeline from its UUID and user's organisation.
  """
  @spec get_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def get_pipeline(%User{current_org_id: org_id}, <<_::288>> = p_uuid) do
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
      stages: [[content_type: [{:fields, :field_type}]], :data_template, :state, :form_mapping]
    ])
  end

  @doc """
  Updates a pipeline.
  """
  @spec pipeline_update(Pipeline.t(), User.t(), map) :: Pipeline.t()
  def pipeline_update(%Pipeline{} = pipeline, %User{} = user, params) do
    pipeline
    |> Pipeline.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, pipeline} ->
        create_pipe_stages(user, pipeline, params)

        Repo.preload(pipeline, [
          :creator,
          stages: [
            [content_type: [{:fields, :field_type}]],
            :data_template,
            :state,
            :form_mapping
          ]
        ])

      {:error, _} = changeset ->
        changeset
    end
  end

  def pipeline_update(_, _, _), do: nil

  @doc """
  Delete a pipeline.
  """
  @spec delete_pipeline(Pipeline.t()) :: {:ok, Pipeline.t()} | {:error, Ecto.Changeset.t()} | nil
  def delete_pipeline(%Pipeline{} = pipeline) do
    Forms.delete_form_pipeline(pipeline)
    Repo.delete(pipeline)
  end

  def delete_pipeline(_), do: nil

  @doc """
  Get a pipeline stage from its UUID and user's organisation.
  """
  @spec get_pipe_stage(User.t(), Ecto.UUID.t()) :: Stage.t() | nil
  def get_pipe_stage(%User{current_org_id: org_id}, <<_::288>> = s_uuid) do
    query =
      from(s in Stage,
        join: p in Pipeline,
        on: p.organisation_id == ^org_id and s.pipeline_id == p.id,
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
        "data_template_id" => d_uuid
      }) do
    c_type = get_content_type(current_user, c_uuid)
    d_temp = get_d_template(current_user, d_uuid)

    do_update_pipe_stage(stage, c_type, d_temp)
  end

  def update_pipe_stage(_, _, _), do: nil

  # Update a stage.
  @spec do_update_pipe_stage(Stage.t(), ContentType.t(), DataTemplate.t()) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_update_pipe_stage(stage, %ContentType{id: c_id}, %DataTemplate{id: d_id}) do
    stage
    |> Stage.update_changeset(%{content_type_id: c_id, data_template_id: d_id})
    |> Repo.update()
  end

  defp do_update_pipe_stage(_, _, _), do: nil

  @doc """
  Deletes a pipe stage.
  """
  @spec delete_pipe_stage(Stage.t()) :: {:ok, Stage.t()} | nil
  def delete_pipe_stage(%Stage{} = pipe_stage), do: Repo.delete(pipe_stage)

  def delete_pipe_stage(_), do: nil

  @doc """
  Preload all datas of a pipe stage excluding pipeline.
  """
  @spec preload_stage_details(Stage.t()) :: Stage.t()
  def preload_stage_details(stage) do
    Repo.preload(stage, [
      {:content_type, fields: [:field_type]},
      :data_template,
      :state,
      :form_mapping
    ])
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
  @spec get_trigger_histories_of_a_pipeline(Pipeline.t(), map) :: Scrivener.Page.t()
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
   Get all the triggers under a organisation.
  """
  @spec trigger_history_index(User.t(), map) :: Scrivener.Page.t()
  def trigger_history_index(%User{current_org_id: org_id} = _user, params) do
    TriggerHistory
    |> join(:inner, [t], p in Pipeline, on: t.pipeline_id == p.id, as: :pipeline)
    |> where([pipeline: p], p.organisation_id == ^org_id)
    |> where(^trigger_history_filter_by_pipeline_name(params))
    |> where(^trigger_history_filter_by_status(params))
    |> order_by(^trigger_history_sort(params))
    |> preload([:creator])
    |> Repo.paginate(params)
  end

  def trigger_history_index(_, _), do: nil

  defp trigger_history_filter_by_pipeline_name(%{"pipeline_name" => pipeline_name} = _params),
    do: dynamic([pipeline: p], ilike(p.name, ^"%#{pipeline_name}%"))

  defp trigger_history_filter_by_pipeline_name(_), do: true

  defp trigger_history_filter_by_status(%{"status" => status} = _params),
    do: dynamic([t], t.state == ^status)

  defp trigger_history_filter_by_status(_), do: true

  defp trigger_history_sort(%{"sort" => "pipeline_name"} = _params),
    do: [asc: dynamic([pipeline: p], p.name)]

  defp trigger_history_sort(%{"sort" => "pipeline_name_desc"} = _params),
    do: [desc: dynamic([pipeline: p], p.name)]

  defp trigger_history_sort(%{"sort" => "status"} = _params), do: [asc: dynamic([t], t.state)]

  defp trigger_history_sort(%{"sort" => "status_desc"} = _params),
    do: [desc: dynamic([t], t.state)]

  defp trigger_history_sort(%{"sort" => "inserted_at"} = _params),
    do: [asc: dynamic([t], t.inserted_at)]

  defp trigger_history_sort(%{"sort" => "inserted_at_desc"} = _params),
    do: [desc: dynamic([t], t.inserted_at)]

  defp trigger_history_sort(_), do: []

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
    query = from(r in Role, where: r.id == ^id, join: ct in ContentType, on: ct.id == ^c_id)

    Repo.one(query)
  end

  @doc """
  get the content type from the respective role
  """

  def get_content_type_role(id, role_id) do
    query = from(ct in ContentType, where: ct.id == ^id, join: r in Role, on: r.id == ^role_id)

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
  # TODO improve tests
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

  def get_collection_form_field(%{current_org_id: org_id}, id) do
    query =
      from(cff in CollectionFormField,
        join: cf in CollectionForm,
        on: cff.collection_form_id == cf.id,
        where: cff.id == ^id and cf.organisation_id == ^org_id
      )

    case Repo.one(query) do
      %CollectionFormField{} = collection_form_field ->
        collection_form_field

      _ ->
        {:error, :invalid_id, "CollectionFormField"}
    end
  end

  def get_collection_form_field(_, _), do: {:error, :fake}

  def create_collection_form_field(c_form_id, params) do
    params = Map.put(params, "collection_form_id", c_form_id)

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

  @doc """
  Return collection form by user and collection form id
  ## Parameters
  * User - user struct
  * id - Collection form field
  """
  def get_collection_form(%{current_org_id: org_id}, <<_::288>> = id) do
    case Repo.get_by(CollectionForm, id: id, organisation_id: org_id) do
      %CollectionForm{} = collection_form ->
        collection_form

      _ ->
        {:error, :invalid_id, "CollectionForm"}
    end
  end

  def get_collection_form(_, _), do: {:error, :invalid_id, "CollectionForm"}

  def create_collection_form(%{id: usr_id, current_org_id: org_id}, params) do
    params = Map.merge(params, %{"creator_id" => usr_id, "organisation_id" => org_id})

    %CollectionForm{}
    |> CollectionForm.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %CollectionForm{} = collection_form} ->
        Repo.preload(collection_form, [:fields, :creator])

      changeset = {:error, _} ->
        changeset
    end
  end

  # defp create_form_fields(collection_form, fields) do
  #   Enum.each(fields, fn x -> create_collection_form_field(collection_form.id, x) end)
  # end

  def update_collection_form(collection_form, params) do
    collection_form
    |> Repo.preload(:fields)
    |> CollectionForm.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, collection_form} ->
        Repo.preload(collection_form, [:creator, :fields])
    end
  end

  def delete_collection_form(%CollectionForm{} = collection_form) do
    Repo.delete(collection_form)
  end

  def list_collection_form(%{current_org_id: org_id}, params) do
    query = from(c in CollectionForm, preload: [:fields], where: c.organisation_id == ^org_id)
    Repo.paginate(query, params)
  end

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

  @spec has_access?(User.t(), Ecto.UUID.t(), String.t()) :: boolean() | {:error, String.t()}
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

  @doc """
  Get counterparty for a contract document
  """
  @spec get_counterparty(String.t(), String.t()) :: CounterParties.t() | nil
  def get_counterparty(document_id, counterparty_id) do
    Repo.get_by(CounterParties, content_id: document_id, counterparty_id: counterparty_id)
  end

  @doc """
   Add counterparty to content
  """
  def add_counterparty(%Instance{id: content_id}, %{
        "guest_user_id" => guest_user_id,
        "name" => name
      }) do
    CounterParties
    |> CounterParties.changeset(%{
      name: name,
      content_id: content_id,
      guest_user_id: guest_user_id
    })
    |> Repo.insert()
    |> case do
      {:ok, counter_party} ->
        Repo.preload(counter_party, [:guest_user, :content])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def add_counterparty(_, _), do: nil

  @doc """
    Remove counterparty from content
  """
  @spec remove_counterparty(CounterParties.t()) ::
          {:ok, CounterParties.t()} | {:error, Ecto.Changeset.t()}
  def remove_counterparty(%CounterParties{} = counterparty) do
    Repo.delete(counterparty)
  end
end
