defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto

  alias WraftDoc.{
    Repo,
    Account.User,
    Document.Layout,
    Document.ContentType,
    Document.Engine,
    Document.Instance,
    Enterprise.Flow
  }

  @doc """
  Create a layout.
  """
  @spec create_layout(%User{}, %Engine{}, map) :: %Layout{} | {:error, Ecto.Changeset.t()}
  def create_layout(current_user, engine, params) do
    current_user
    |> build_assoc(:layouts, engine: engine)
    |> Layout.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, layout} ->
        layout |> Repo.preload(:engine)

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Create a content type.
  """
  @spec create_content_type(%User{}, map) :: %ContentType{} | {:error, Ecto.Changeset.t()}
  def create_content_type(current_user, params) do
    current_user
    |> build_assoc(:content_types)
    |> ContentType.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        content_type |> Repo.preload(:layout)

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  List all engines.
  """
  @spec engines_list() :: list
  def engines_list() do
    Repo.all(Engine)
  end

  @doc """
  List all layouts.
  """
  @spec layout_index() :: list
  def layout_index() do
    Repo.all(Layout) |> Repo.preload(:engine)
  end

  @doc """
  Show a layout.
  """
  @spec show_layout(binary) :: %Layout{engine: %Engine{}, creator: %User{}}
  def show_layout(uuid) do
    get_layout(uuid)
    |> Repo.preload([:engine, :creator])
  end

  @doc """
  Get a layout from its UUID.
  """
  @spec get_layout(binary) :: %Layout{}
  def get_layout(uuid) do
    Repo.get_by(Layout, uuid: uuid)
  end

  @doc """
  Update a layout.
  """
  @spec update_layout(%Layout{}, map) :: %Layout{engine: %Engine{}, creator: %User{}}
  def update_layout(layout, %{"engine_uuid" => engine_uuid} = params) do
    %Engine{id: id} = get_engine(engine_uuid)
    {_, params} = Map.pop(params, "engine_uuid")
    params = params |> Map.merge(%{"engine_id" => id})
    update_layout(layout, params)
  end

  def update_layout(layout, params) do
    layout
    |> Layout.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, layout} ->
        layout |> Repo.preload([:engine, :creator])
    end
  end

  @doc """
  Delete a layout.
  """
  @spec delete_layout(%Layout{}) :: {:ok, %Layout{}} | {:error, Ecto.Changeset.t()}
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
  List all content types.
  """
  @spec content_type_index() :: list
  def content_type_index() do
    Repo.all(ContentType) |> Repo.preload(:layout)
  end

  @doc """
  Show a content type.
  """
  @spec show_content_type(binary) :: %ContentType{layout: %Layout{}, creator: %User{}}
  def show_content_type(uuid) do
    get_content_type(uuid)
    |> Repo.preload([:layout, :creator])
  end

  @doc """
  Get a content type from its UUID.
  """
  @spec get_content_type(binary) :: %ContentType{}
  def get_content_type(uuid) do
    Repo.get_by(ContentType, uuid: uuid)
  end

  @doc """
  Update a content type.
  """
  @spec update_content_type(%ContentType{}, map) :: %ContentType{
          layout: %Layout{},
          creator: %User{}
        }
  def update_content_type(content_type, params) do
    content_type
    |> ContentType.changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type} ->
        content_type |> Repo.preload([:layout, :creator])
    end
  end

  @doc """
  Delete a content type.
  """
  @spec delete_content_type(%ContentType{}) ::
          {:ok, %ContentType{}} | {:error, Ecto.Changeset.t()}
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
  Create a new instance.
  """
  @spec create_instance(%User{}, %ContentType{}, map) ::
          %Instance{content_type: %ContentType{}, state: %Flow{}} | {:error, Ecto.Changeset.t()}
  # def create_instance(current_user, c_type, flow, params) do
  def create_instance(current_user, c_type, params) do
    params = params |> Map.merge(%{"instance_id" => Ecto.UUID.generate()})

    c_type
    # |> build_assoc(:instances, state: flow, creator: current_user)
    |> build_assoc(:instances, creator: current_user)
    |> Instance.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, content} ->
        content |> Repo.preload([:content_type, :state])

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Get a flow from its UUID.
  """
  @spec get_flow(binary) :: %Flow{} | nil
  def get_flow(flow_uuid) do
    Repo.get_by(Flow, uuid: flow_uuid)
  end

  @doc """
  Get an engine from its UUID.
  """
  @spec get_engine(binary) :: %Engine{} | nil
  def get_engine(engine_uuid) do
    Repo.get_by(Engine, uuid: engine_uuid)
  end
end
