defmodule WraftDoc.Layouts do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
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
  @spec create_layout(User.t(), Engine.t(), map()) ::
          {:ok, %{layout: Layout.t(), asset: Asset.t()}} | {:error, any()}
  def create_layout(
        %{current_org_id: org_id} = current_user,
        %Engine{id: engine_id} = engine,
        params
      ) do
    Multi.new()
    |> layout_asset_multi(current_user, params)
    |> Multi.run(:layout, fn _repo, %{asset: %{id: asset_id}} ->
      params =
        Map.merge(params, %{
          "engine_id" => engine_id,
          "asset_id" => asset_id,
          "organisation_id" => org_id
        })

      prepare_layout(current_user, engine, params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{asset: asset, layout: layout}} ->
        {:ok, %{asset: asset, layout: layout}}

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  def create_layout(_, _, _), do: {:error, :fake}

  defp prepare_layout(current_user, engine, params) do
    current_user
    |> build_assoc(:layouts, engine: engine)
    |> Layout.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, layout} ->
        layout = layout_files_upload(layout, params)

        {:ok,
         Repo.preload(layout, [
           :engine,
           :creator,
           :asset,
           frame: [:asset, fields: [:field_type]]
         ])}

      changeset = {:error, _} ->
        changeset
    end
  end

  defp layout_asset_multi(
         multi,
         %{current_org_id: org_id} = current_user,
         %{"file" => file, "type" => type, "asset_name" => asset_name} = _params
       )
       when not is_nil(file) do
    Multi.run(multi, :asset, fn _repo, _changes ->
      asset_params = %{
        "organisation_id" => org_id,
        "name" => asset_name,
        "type" => type,
        "file" => file
      }

      Assets.create_asset(current_user, asset_params)
    end)
  end

  defp layout_asset_multi(multi, _, _) do
    Multi.run(multi, :asset, fn _repo, _changes ->
      {:ok, %{id: nil}}
    end)
  end

  @doc """
  Upload layout slug/screenshot file.
  """
  @spec layout_files_upload(Layout.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def layout_files_upload(layout, %{"slug_file" => _} = params),
    do: layout_update_files(layout, params)

  def layout_files_upload(layout, %{"screenshot" => _} = params),
    do: layout_update_files(layout, params)

  def layout_files_upload(layout, _params), do: Repo.preload(layout, [:engine, :creator])

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
        preload: [:engine, :asset, frame: [:asset]]
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
  @spec update_layout(User.t(), Layout.t(), map()) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def update_layout(%{current_org_id: org_id} = current_user, %{asset: asset} = layout, params) do
    Multi.new()
    |> maybe_update_asset(asset, current_user, params)
    |> Multi.update(:layout, fn changes ->
      params =
        params
        |> Map.put("organisation_id", org_id)
        |> maybe_put_asset_id(changes[:asset])

      Layout.update_changeset(layout, params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{layout: layout}} ->
        Assets.preload_asset(layout)

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  defp maybe_update_asset(
         multi,
         nil,
         %{current_org_id: org_id} = current_user,
         %{"file" => file} = params
       )
       when not is_nil(file) do
    Multi.run(multi, :asset, fn _repo, _changes ->
      params =
        Map.merge(params, %{
          "organisation_id" => org_id,
          "name" => params["asset_name"],
          "type" => "layout"
        })

      Assets.create_asset(current_user, params)
    end)
  end

  defp maybe_update_asset(
         multi,
         asset,
         %{current_org_id: org_id} = _current_user,
         %{"file" => file} = _params
       )
       when not is_nil(file) do
    Multi.run(multi, :asset, fn _repo, _changes ->
      params = %{
        "organisation_id" => org_id,
        "name" => file.filename,
        "type" => "layout",
        "file" => file
      }

      Assets.update_asset(asset, params)
    end)
  end

  defp maybe_update_asset(multi, _, _, _), do: multi

  defp maybe_put_asset_id(params, nil), do: params

  defp maybe_put_asset_id(params, %{id: asset_id} = _asset),
    do: Map.put(params, "asset_id", asset_id)

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
