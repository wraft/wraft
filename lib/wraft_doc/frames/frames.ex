defmodule WraftDoc.Frames do
  @moduledoc """
  Module that handles frame related contexts.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Assets
  alias WraftDoc.Client.Minio
  alias WraftDoc.ContentTypes
  alias WraftDoc.Documents
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Frames.FrameAsset
  alias WraftDoc.Layouts
  alias WraftDoc.Repo
  alias WraftDoc.Utils.FileHelper

  @doc """
  Lists all frames.
  """
  @spec list_frames(User.t(), map()) :: map()
  def list_frames(%{current_org_id: organisation_id}, params) do
    query =
      from(s in Frame,
        where: s.organisation_id == ^organisation_id,
        order_by: [desc: s.inserted_at],
        preload: [:assets]
      )

    Repo.paginate(query, params)
  end

  def list_frames(_, _), do: {:error, :fake}

  @doc """
  Retrieves a specific frame.
  """
  @spec get_frame(binary(), User.t()) :: Frame.t() | nil
  def get_frame(<<_::288>> = id, %{current_org_id: organisation_id}) do
    Frame
    |> Repo.get_by(id: id, organisation_id: organisation_id)
    |> Repo.preload([:assets])
  end

  def get_frame(_, _), do: nil

  def get_frame(<<_::288>> = id) do
    Frame
    |> Repo.get_by(id: id)
    |> Repo.preload([:assets])
  end

  def get_frame(_), do: nil

  @doc """
  Create a frame.
  """
  @spec create_frame(User.t(), map()) :: Frame.t() | {:error, Ecto.Changeset.t()}
  def create_frame(%{id: user_id, current_org_id: organisation_id} = current_user, attrs) do
    params =
      Map.merge(attrs, %{
        "organisation_id" => organisation_id,
        "creator_id" => user_id
      })

    Multi.new()
    |> Multi.insert(:frame, Frame.changeset(%Frame{}, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{frame: frame}} ->
        frame_thumbnail_upload(frame, params)
        fetch_and_associate_assets(frame, current_user, params)
        {:ok, Repo.preload(frame, [:assets])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Update a frame.
  """
  @spec update_frame(Frame.t(), User.t(), map()) :: Frame.t() | {:error, Ecto.Changeset.t()}
  def update_frame(
        %Frame{} = frame,
        %{id: user_id, current_org_id: organisation_id} = current_user,
        attrs
      ) do
    frame
    |> Frame.update_changeset(
      Map.merge(attrs, %{
        "organisation_id" => organisation_id,
        "creator_id" => user_id
      })
    )
    |> Repo.update()
    |> case do
      {:ok, frame} ->
        frame_thumbnail_upload(frame, attrs)
        fetch_and_associate_assets(frame, current_user, attrs)
        {:ok, Repo.preload(frame, [:assets])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Delete a frame.
  """
  @spec delete_frame(Frame.t()) :: {:ok, Frame.t()} | {:error, Ecto.Changeset.t()}
  def delete_frame(%Frame{id: frame_id, organisation_id: organisation_id} = frame) do
    case Minio.delete_file("organisations/#{organisation_id}/frames/#{frame_id}") do
      {:ok, _} ->
        Repo.delete(frame)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_and_associate_assets(frame, current_user, %{"assets" => assets}) do
    (assets || "")
    |> String.split(",")
    |> Stream.map(fn asset_id -> Assets.get_asset(asset_id, current_user) end)
    |> Stream.map(fn asset -> associate_frame_and_asset(frame, current_user, asset) end)
    |> Stream.map(fn frame -> add_frame_wraft_json(frame) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_assets(_frame, _current_user, _params), do: nil

  defp associate_frame_and_asset(%Frame{} = frame, current_user, asset) do
    frame
    |> build_assoc(:frame_asset, asset_id: asset.id, creator: current_user)
    |> FrameAsset.changeset()
    |> Repo.insert()

    Repo.preload(frame, [:assets])
  end

  defp associate_frame_and_asset(_frame, _current_user, nil), do: nil

  def add_frame_wraft_json(
        %Frame{
          organisation_id: organisation_id,
          assets: [%{id: asset_id, file: file} | _]
        } = frame
      ) do
    binary =
      Minio.get_object("organisations/#{organisation_id}/assets/#{asset_id}/#{file.file_name}")

    # validated json so wraftjson wont be empty
    {:ok, wraft_json} = FileHelper.get_wraft_json(binary)

    frame
    |> Frame.update_changeset(%{"wraft_json" => wraft_json})
    |> Repo.update()
  end

  @doc """
  Upload frame preview file.
  """
  @spec frame_thumbnail_upload(Frame.t(), map()) ::
          {:ok, %Frame{}} | {:error, Ecto.Changeset.t()}
  def frame_thumbnail_upload(frame, %{"thumbnail" => _} = params) do
    frame |> Frame.file_changeset(params) |> Repo.update()
  end

  def frame_thumbnail_upload(frame, _params) do
    {:ok, frame}
  end

  @doc """
  Retrieves the appropriate engine based on the given frame.
  """
  @spec get_engine_by_frame_type(map()) :: Engine.t() | {:error, :invalid_id, Frame}
  def get_engine_by_frame_type(%{"frame_id" => frame_id}) when frame_id != nil do
    frame_id
    |> get_frame()
    |> case do
      %{type: :typst} = _frame ->
        Documents.get_engine_by_name("Pandoc + Typst")

      %{type: :latex} = _frame ->
        Documents.get_engine_by_name("Pandoc")

      _ ->
        {:error, :invalid_id, Frame}
    end
  end

  def get_engine_by_frame_type(%{"engine_id" => engine_id}), do: Documents.get_engine(engine_id)

  def add_frame_variant_fields(
        %Frame{wraft_json: %{"fields" => frame_fields}},
        %{"fields" => fields} = params
      ) do
    frame_fields = ContentTypes.create_field_params_from_wraft_json(frame_fields)

    Map.put(params, "fields", frame_fields ++ fields)
  end

  def add_frame_variant_fields(_, params), do: params

  def update_frame_variant_fields(
        %{layout: %{id: existing_layout_id, frame: existing_frame}} = content_type,
        current_user,
        %{"fields" => fields, "layout_id" => layout_id} = params
      ) do
    %{frame: new_frame} = _new_layout = Layouts.get_layout(layout_id, current_user)

    cond do
      existing_layout_id == layout_id ->
        params

      is_nil(existing_frame) and is_nil(new_frame) ->
        params

      is_nil(existing_frame) and not is_nil(new_frame) ->
        %Frame{wraft_json: %{"fields" => json_frame_fields}} = new_frame

        frame_fields = ContentTypes.create_field_params_from_wraft_json(json_frame_fields)
        Map.put(params, "fields", frame_fields ++ fields)

      not is_nil(existing_frame) and is_nil(new_frame) ->
        delete_frame_fields(existing_frame, content_type)

        params

      true ->
        delete_frame_fields(existing_frame, content_type)

        %Frame{wraft_json: %{"fields" => frame_fields}} = new_frame

        frame_fields
        |> ContentTypes.create_field_params_from_wraft_json()
        |> then(&Map.put(params, "fields", fields ++ &1))
    end
  end

  defp delete_frame_fields(frame, content_type) do
    %Frame{wraft_json: %{"fields" => frame_fields}} = frame

    frame_field_names = Enum.map(frame_fields, fn field -> field["name"] end)

    query =
      from(ctf in WraftDoc.ContentTypes.ContentTypeField,
        join: f in assoc(ctf, :field),
        where: ctf.content_type_id == ^content_type.id,
        where: f.name in ^frame_field_names,
        preload: [field: f]
      )

    query
    |> Repo.all()
    |> Enum.each(fn content_type_field ->
      ContentTypes.delete_content_type_field(content_type_field)
    end)
  end
end
