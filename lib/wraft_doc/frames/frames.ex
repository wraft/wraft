defmodule WraftDoc.Frames do
  @moduledoc """
  Module that handles frame related contexts.
  """
  import Ecto
  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.Client.Minio
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Documents
  alias WraftDoc.Fields
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Frames.FrameAsset
  alias WraftDoc.Frames.FrameField
  alias WraftDoc.Frames.FrameMapping
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Utils.FileHelper

  @doc """
  Lists all frames.
  """
  @spec list_frames(User.t(), map()) :: map()
  def list_frames(%User{current_org_id: organisation_id}, params) do
    Frame
    |> where([frame], frame.organisation_id == ^organisation_id)
    |> order_by([frame], desc: frame.inserted_at)
    |> preload([:assets, :frame_mappings, fields: [:field_type]])
    |> Repo.paginate(params)
  end

  def list_frames(_, _), do: {:error, :fake}

  @doc """
  Retrieves a specific frame.
  """
  @spec get_frame(binary(), User.t()) :: Frame.t() | nil
  def get_frame(<<_::288>> = id, %User{current_org_id: organisation_id}) do
    Frame
    |> Repo.get_by(id: id, organisation_id: organisation_id)
    |> Repo.preload([:assets, :frame_mappings, fields: [:field_type]])
  end

  def get_frame(_, _), do: nil

  def get_frame(<<_::288>> = id) do
    Frame
    |> Repo.get_by(id: id)
    |> Repo.preload([:assets, :frame_mappings, fields: [:field_type]])
  end

  def get_frame(_), do: nil

  @doc """
  Create a frame.
  """
  @spec create_frame(User.t() | nil, map()) :: Frame.t() | {:error, Ecto.Changeset.t()}
  def create_frame(
        %User{id: user_id, current_org_id: organisation_id} = current_user,
        asset,
        params
      ) do
    with {:ok, params} <-
           params
           |> Map.merge(%{
             "organisation_id" => organisation_id,
             "creator_id" => user_id
           })
           |> get_frame_params(asset),
         {:ok, frame} <- create_frame_with_params(current_user, params) do
      {:ok, frame}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def create_frame(nil, params), do: create_frame_with_params(nil, params)

  defp create_frame_with_params(current_user, params) do
    Multi.new()
    |> Multi.insert(:frame, Frame.changeset(%Frame{}, params))
    |> Multi.run(:frame_assets, fn _repo, %{frame: frame} ->
      fetch_and_associate_assets(frame, current_user, params)

      {:ok, frame}
    end)
    |> Multi.run(:frame_field, fn _repo,
                                  %{
                                    frame: %Frame{wraft_json: %{"fields" => frame_fields}} = frame
                                  } ->
      fields = create_field_params_from_wraft_json(frame_fields)
      fetch_and_associate_fields(frame, %{"fields" => fields})
      {:ok, frame}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{frame: frame}} ->
        {:ok, Repo.preload(frame, [:assets, :frame_mappings, fields: [:field_type]])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp fetch_and_associate_fields(frame, %{"fields" => fields}) do
    fields
    |> Stream.map(fn x -> create_field_for_frame(frame, x) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_fields(_frame, _params), do: nil

  defp create_field_for_frame(
         frame,
         %{"field_type_id" => field_type_id} = params
       ) do
    field_type_id
    |> Fields.get_field_type()
    |> case do
      %FieldType{} = field_type ->
        create_frame_field(field_type, frame, params)

      _ ->
        nil
    end
  end

  defp create_field_for_frame(_frame, _field), do: nil

  defp create_frame_field(field_type, frame, params) do
    params = Map.merge(params, %{"organisation_id" => frame.organisation_id})

    Multi.new()
    |> Multi.run(:field, fn _, _ -> Fields.create_field(field_type, params) end)
    |> Multi.insert(:frame_field, fn %{field: field} ->
      FrameField.changeset(%FrameField{}, %{
        frame_id: frame.id,
        field_id: field.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, step, error, _} ->
        Logger.error("Frame field creation failed in step #{inspect(step)}", error: error)
        :error
    end
  end

  @doc """
  Update a frame.
  """
  @spec update_frame(Frame.t(), User.t() | nil, map()) ::
          {:ok, Frame.t()} | {:error, Ecto.Changeset.t()}
  def update_frame(
        %Frame{} = frame,
        asset,
        %User{id: user_id, current_org_id: organisation_id} = current_user,
        params
      ) do
    with {:ok, params} <-
           params
           |> Map.merge(%{
             "organisation_id" => organisation_id,
             "creator_id" => user_id
           })
           |> get_frame_params(asset),
         {:ok, frame} <- update_frame_with_params(frame, current_user, params) do
      {:ok, frame}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update_frame(%Frame{} = frame, nil, params),
    do: update_frame_with_params(frame, nil, params)

  defp update_frame_with_params(frame, current_user, params) do
    Multi.new()
    |> Multi.update(:frame, Frame.update_changeset(%Frame{} = frame, params))
    |> Multi.run(:frame_asset, fn _repo,
                                  %{
                                    frame: frame
                                  } ->
      delete_frame_assets(frame)
      fetch_and_associate_assets(frame, current_user, params)
      {:ok, frame}
    end)
    |> Multi.run(:frame_field, fn _repo,
                                  %{
                                    frame: %Frame{wraft_json: %{"fields" => frame_fields}} = frame
                                  } ->
      delete_frame_fields(frame)

      frame_fields
      |> create_field_params_from_wraft_json()
      |> then(&fetch_and_associate_fields(frame, %{"fields" => &1}))

      {:ok, frame}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{frame_field: frame}} ->
        {:ok, Repo.preload(frame, [:assets, fields: [:field_type]])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Delete a frame.
  """
  @spec delete_frame(Frame.t()) :: {:ok, Frame.t()} | {:error, Ecto.Changeset.t()}
  def delete_frame(
        %Frame{
          organisation_id: organisation_id,
          assets: [%{id: asset_id, file: %{file_name: file_name}} | _]
        } = frame
      ) do
    case Minio.delete_file("organisations/#{organisation_id}/assets/#{asset_id}/#{file_name}") do
      {:ok, _} ->
        Repo.delete(frame)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_and_associate_assets(frame, current_user, %{"assets" => asset_id}) do
    asset_id
    |> Assets.get_asset(current_user)
    |> then(&associate_frame_and_asset(frame, current_user, &1))
  end

  defp fetch_and_associate_assets(_frame, _current_user, _params), do: nil

  defp associate_frame_and_asset(%Frame{} = frame, current_user, asset) do
    frame
    |> build_assoc(:frame_asset, asset_id: asset.id, creator: current_user)
    |> FrameAsset.changeset()
    |> Repo.insert()

    Repo.preload(frame, [:assets, fields: [:field_type]])
  end

  defp associate_frame_and_asset(_frame, _current_user, nil), do: nil

  defp get_frame_params(
         params,
         %{id: asset_id, organisation_id: organisation_id, file: %{file_name: file_name}}
       ) do
    binary =
      Minio.get_object("organisations/#{organisation_id}/assets/#{asset_id}/#{file_name}")

    file_size = FileHelper.file_size(binary)

    {:ok, %{"metadata" => %{"frameType" => type} = metadata} = wraft_json} =
      FileHelper.get_wraft_json(binary)

    params =
      params
      |> Map.merge(metadata)
      |> Map.merge(%{"wraft_json" => wraft_json, "file_size" => file_size, "type" => type})

    {:ok, params}
  rescue
    error -> {:error, error.message}
  end

  @doc """
  Retrieves the appropriate engine based on the given frame.
  """
  @spec get_engine_by_frame_type(map()) :: Engine.t() | {:error, :invalid_id, Frame}
  def get_engine_by_frame_type(%{"frame_id" => <<_::288>> = frame_id}) do
    frame_id
    |> get_frame()
    |> case do
      %{type: :typst} = _frame -> Documents.get_engine_by_name("Pandoc + Typst")
      %{type: :latex} = _frame -> Documents.get_engine_by_name("Pandoc")
      _ -> {:error, :invalid_id, Frame}
    end
  end

  def get_engine_by_frame_type(%{"engine_id" => engine_id}), do: Documents.get_engine(engine_id)

  @doc """
  Create a content type field from wraft_json.
  """
  @spec create_field_params_from_wraft_json(list()) :: list()
  def create_field_params_from_wraft_json(wraft_json_fields) do
    field_types = Repo.all(from(ft in FieldType, select: {ft.name, ft.id}))
    field_type_map = Map.new(field_types)

    Enum.map(wraft_json_fields, fn field ->
      field_type = String.capitalize(field["type"])

      %{
        "field_type_id" => Map.get(field_type_map, field_type),
        "key" => field["name"],
        "name" => field["name"]
      }
    end)
  end

  defp delete_frame_fields(%Frame{id: frame_id}) do
    FrameField
    |> where([frame_field], frame_field.frame_id == ^frame_id)
    |> preload([:field])
    |> Repo.all()
    |> Enum.each(fn frame_field ->
      delete_frame_field(frame_field)
    end)
  end

  defp delete_frame_field(frame_field) do
    %FrameField{field: field} = Repo.preload(frame_field, :field)
    Repo.delete(field)
    Repo.delete(frame_field)
    :ok
  end

  defp delete_frame_assets(%Frame{id: frame_id}) do
    frame_assets =
      FrameAsset
      |> where([frame_asset], frame_asset.frame_id == ^frame_id)
      |> preload([:asset])
      |> Repo.all()

    Enum.each(frame_assets, fn frame_asset ->
      Repo.delete(frame_asset)
      Repo.delete(frame_asset.asset)
    end)
  end

  @doc """
    Create frame mapping
  """
  @spec create_frame_mapping(map()) :: {:ok, FrameMapping.t()} | {:error, Ecto.Changeset.t()}
  def create_frame_mapping(params) do
    %FrameMapping{}
    |> FrameMapping.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, frame_mapping} ->
        {:ok, frame_mapping}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Get frame mapping
  """
  @spec get_frame_mapping(User.t(), map()) :: FrameMapping.t() | nil
  def get_frame_mapping(
        %User{current_org_id: org_id},
        %{"mapping_id" => mapping_id, "frame_id" => frame_id} = _params
      ) do
    FrameMapping
    |> join(:inner, [fp], f in Frame, on: f.id == fp.frame_id and f.organisation_id == ^org_id)
    |> where([fp], fp.id == ^mapping_id and fp.frame_id == ^frame_id)
    |> Repo.one()
  end

  def get_frame_mapping(_, _), do: nil

  @doc """
    Update frame mapping
  """
  @spec update_frame_mapping(FrameMapping.t(), map()) ::
          {:ok, FrameMapping.t()} | {:error, Ecto.Changeset.t()}
  def update_frame_mapping(frame_mapping, params) do
    frame_mapping
    |> FrameMapping.update_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, frame_mapping} ->
        {:ok, frame_mapping}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
    Transform data by frame mapping
  """
  @spec transform_data_by_mapping(FrameMapping.t(), map()) :: map() | {:error, String.t()}
  def transform_data_by_mapping(%FrameMapping{mapping: mappings} = _frame_mapping, data) do
    mappings
    |> transform_mappings
    |> transform_data(data)
  end

  def transform_data_by_mapping(nil, _data), do: {:error, "No mappings found"}

  defp transform_mappings(mappings) do
    Enum.reduce(mappings, %{}, fn %{
                                    destination: %{"name" => destination_name},
                                    source: %{"name" => source_name}
                                  },
                                  acc ->
      Map.put(acc, destination_name, source_name)
    end)
  end

  defp transform_data(mappings, data) do
    data = Jason.decode!(data)

    Enum.reduce(mappings, %{}, fn {frame_field_name, variant_field_name}, acc ->
      frame_field_name =
        frame_field_name
        |> String.downcase()
        |> String.replace(" ", "_")

      case Map.get(data, String.downcase(variant_field_name)) do
        nil -> acc
        value -> Map.put(acc, frame_field_name, value)
      end
    end)
  end

  @spec check_frame_mapping(ContentType.t()) :: :ok | {:error, map() | String.t()}
  def check_frame_mapping(%ContentType{layout: %Layout{frame: nil}} = _content_type), do: :ok

  def check_frame_mapping(%ContentType{
        layout: %Layout{frame: %Frame{frame_mappings: nil}}
      }),
      do: {:error, "Frame mappings are missing"}

  def check_frame_mapping(%ContentType{
        fields: content_type_fields,
        layout: %Layout{
          frame: %Frame{
            frame_fields: frame_fields,
            frame_mappings: %{mapping: mappings}
          }
        }
      })
      when is_list(mappings) do
    frame_field_map =
      frame_fields
      |> Enum.map(fn %{
                       field_id: field_id,
                       field: %{name: name}
                     } ->
        {field_id, name}
      end)
      |> Map.new()

    content_type_field_map =
      content_type_fields
      |> Enum.map(fn %{id: id, name: name} ->
        {id, name}
      end)
      |> Map.new()

    mapping_source_ids =
      mappings
      |> Enum.map(fn
        %{source: %{"id" => source_id}} -> source_id
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    mapping_destination_ids =
      mappings
      |> Enum.map(fn
        %{destination: %{"id" => destination_id}} ->
          destination_id

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    missing_content_type_field_names =
      mappings
      |> Enum.reduce([], fn %{
                              source: %{"id" => source_id, "name" => name}
                            },
                            acc ->
        if source_id in Map.keys(content_type_field_map) do
          acc
        else
          [name | acc]
        end
      end)
      |> Enum.uniq()

    missing_frame_field_names =
      mappings
      |> Enum.reduce([], fn %{
                              destination: %{"id" => destination_id, "name" => name}
                            },
                            acc ->
        if destination_id in Map.keys(frame_field_map) do
          acc
        else
          [name | acc]
        end
      end)
      |> Enum.uniq()

    missing_source_ids = Map.keys(content_type_field_map) -- mapping_source_ids
    missing_destination_ids = Map.keys(frame_field_map) -- mapping_destination_ids

    missing_source_names = Enum.map(missing_source_ids, &content_type_field_map[&1])
    missing_destination_names = Enum.map(missing_destination_ids, &frame_field_map[&1])

    build_error_response(
      missing_source_names,
      missing_destination_names,
      missing_content_type_field_names,
      missing_frame_field_names
    )
  end

  defp build_error_response([], [], [], []), do: :ok

  defp build_error_response(
         missing_source_names,
         missing_destination_names,
         missing_content_type_field_names,
         missing_frame_field_names
       ) do
    {:error,
     Enum.reduce(
       %{
         missing_source_fields: missing_source_names,
         missing_destination_fields: missing_destination_names,
         missing_content_type_fields: missing_content_type_field_names,
         missing_frame_fields: missing_frame_field_names
       },
       %{},
       fn {key, value}, acc ->
         if value != [] do
           Map.put(acc, key, value)
         else
           acc
         end
       end
     )}
  end
end
