defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  alias WraftDoc.{Repo, Account.User, Document.Layout, Document.ContentType, Document.Engine}

  @doc """
  Create a layout.
  """
  @spec create_layout(%User{}, map) :: %Layout{} | {:error, Ecto.Changeset.t()}
  def create_layout(current_user, params) do
    current_user
    |> build_assoc(:layouts)
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
  def update_layout(layout, params) do
    layout
    |> Layout.changeset(params)
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
        "Cannot delete the layout. Some Content types depend on this layout. Update those content types and then try again.!.!"
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
end
