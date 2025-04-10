defmodule WraftDoc.Layouts do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Documents.Engine
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Repo

  @doc """
  Create a layout.
  """
  # TODO - improve tests
  @spec create_layout(User.t(), Engine.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def create_layout(%{current_org_id: org_id} = current_user, %{id: engine_id} = engine, params) do
    params = Map.merge(params, %{"organisation_id" => org_id, "engine_id" => engine_id})

    current_user
    |> build_assoc(:layouts, engine: engine)
    |> Layout.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, layout} ->
        layout = layout_files_upload(layout, params)
        fetch_and_associcate_assets(layout, current_user, params)

        Repo.preload(layout, [
          :engine,
          :creator,
          :assets,
          frame: [:asset, fields: [:field_type]]
        ])

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
    |> Stream.map(fn x -> Assets.get_asset(x, current_user) end)
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
        preload: [:engine, :assets, frame: [:asset, fields: [:field_type]]]
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
      Assets.preload_asset(layout)
    end
  end

  @doc """
  Get a layout from its UUID.
  """
  @spec get_layout(binary, User.t()) :: Layout.t()
  def get_layout(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Layout, id: id, organisation_id: org_id) do
      %Layout{} = layout ->
        Assets.preload_asset(layout)

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

        Repo.preload(layout, [
          :engine,
          :creator,
          :assets,
          frame: [:asset, fields: [:field_type]]
        ])
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
end
