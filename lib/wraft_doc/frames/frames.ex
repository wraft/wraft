defmodule WraftDoc.Frames do
  @moduledoc """
  Module that handles frame related contexts.
  """

  import Ecto.Query
  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Client.Minio
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Documents
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Utils.FileHelper
  alias WraftDoc.Utils.FileValidator

  @doc """
  Lists all frames.
  """
  @spec list_frames(User.t(), map()) :: map()
  def list_frames(%User{current_org_id: organisation_id}, params) do
    Frame
    |> where([frame], frame.organisation_id == ^organisation_id)
    |> order_by([frame], desc: frame.inserted_at)
    |> preload([:asset])
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
    |> Repo.preload([:asset])
  end

  def get_frame(_, _), do: nil

  def get_frame(<<_::288>> = id) do
    Frame
    |> Repo.get_by(id: id)
    |> Repo.preload([:asset])
  end

  def get_frame(_), do: nil

  @doc """
  Checks if a frame name already exists
  """
  @spec frame_name_exists?(String.t(), User.t()) :: boolean()
  def frame_name_exists?(name, %User{current_org_id: organisation_id}),
    do:
      Repo.exists?(
        from(f in Frame, where: f.name == ^name and f.organisation_id == ^organisation_id)
      )

  @doc """
  Create a frame.
  """
  @spec create_frame(User.t() | nil, map()) :: Frame.t() | {:error, Ecto.Changeset.t()}
  def create_frame(
        %User{id: user_id, current_org_id: organisation_id} = current_user,
        %{"file" => %{path: file_path} = file} = params
      ) do
    with {:ok, _} <- FileValidator.validate_file(file_path),
         {:ok, metadata} <- FileHelper.get_file_metadata(file),
         :ok <- FileHelper.validate_frame_file(file),
         {:ok, params} <- process_frame_params(Map.merge(params, metadata)),
         {:ok, %Frame{} = frame} <-
           create_frame_multi(
             current_user,
             Map.merge(params, %{
               "organisation_id" => organisation_id,
               "creator_id" => user_id
             })
           ) do
      {:ok, frame}
    end
  end

  def create_frame(nil, params), do: create_frame_multi(nil, params)

  defp create_frame_multi(current_user, params) do
    Multi.new()
    |> Multi.run(:asset, fn _, _ ->
      Assets.create_asset(current_user, Map.merge(params, %{"type" => "frame"}))
    end)
    |> Multi.insert(:frame, fn %{asset: %Asset{id: asset_id}} ->
      Frame.changeset(%Frame{}, Map.put(params, "asset_id", asset_id))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{frame: frame}} ->
        {:ok, Repo.preload(frame, [:asset])}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Update a frame.
  """
  @spec update_frame(Frame.t(), map()) ::
          {:ok, Frame.t()} | {:error, Ecto.Changeset.t() | String.t()}
  def update_frame(
        %Frame{fields: existing_fields} = frame,
        %{"file" => %{path: file_path} = file} = params
      ) do
    with {:ok, _} <- FileValidator.validate_file(file_path),
         {:ok, metadata} <- FileHelper.get_file_metadata(file),
         :ok <- FileHelper.validate_frame_file(file),
         {:ok, %{"fields" => fields} = params} <-
           process_frame_params(Map.merge(params, metadata)),
         :ok <- validate_fields(existing_fields, fields),
         {:ok, %Frame{} = frame} <- update_frame_multi(frame, params) do
      {:ok, frame}
    end
  end

  defp update_frame_multi(%{asset: asset} = frame, params) do
    Multi.new()
    |> Multi.run(:frame_asset, fn _repo, _ ->
      Assets.update_asset(asset, params)
      {:ok, frame}
    end)
    |> Multi.update(:frame, Frame.update_changeset(%Frame{} = frame, params))
    |> Repo.transaction()
    |> case do
      {:ok, %{frame: frame}} ->
        {:ok, frame}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp validate_fields(existing_fields, incoming_fields) do
    if Enum.sort(existing_fields) == Enum.sort(incoming_fields) do
      :ok
    else
      {:error, "Frame can't be updated, detected changes in fields."}
    end
  end

  @doc """
  Delete a frame.
  """
  @spec delete_frame(Frame.t()) :: {:ok, Frame.t()} | {:error, Ecto.Changeset.t()}
  def delete_frame(
        %Frame{
          organisation_id: organisation_id,
          asset: %{id: asset_id, file: %{file_name: file_name}}
        } = frame
      ) do
    case Minio.delete_file("organisations/#{organisation_id}/assets/#{asset_id}/#{file_name}") do
      {:ok, _} ->
        Repo.delete(frame)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Process the frame binary and update the frame params.
  """
  @spec process_frame_params(map()) :: {:ok, map()}
  def process_frame_params(%{"file" => %{path: file_path}} = params) do
    file_binary = File.read!(file_path)
    file_size = FileHelper.file_size(file_binary)

    {:ok, %{"metadata" => %{"frameType" => type}, "fields" => fields} = wraft_json} =
      FileHelper.get_wraft_json(file_binary)

    params
    |> Map.merge(%{
      "wraft_json" => wraft_json,
      "file_size" => file_size,
      "type" => type,
      "fields" => fields
    })
    |> then(&{:ok, &1})
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
    Transform data by frame mapping
  """
  @spec transform_data_by_mapping(list(), map()) :: map() | {:error, String.t()}

  def transform_data_by_mapping(nil, _data), do: {:error, "No mappings found"}

  def transform_data_by_mapping(mappings, data) do
    mappings
    |> transform_mappings
    |> transform_data(data)
  end

  defp transform_mappings(mappings) do
    Enum.reduce(mappings, %{}, fn %{
                                    "destination" => destination_name,
                                    "source" => source_name
                                  },
                                  acc ->
      Map.put(acc, destination_name, source_name)
    end)
  end

  defp transform_data(mappings, data) do
    data = Jason.decode!(data)

    Enum.reduce(mappings, %{}, fn {frame_field_name, variant_field_name}, acc ->
      case Map.get(data, format_name(variant_field_name)) do
        nil -> acc
        value -> Map.put(acc, format_name(frame_field_name), value)
      end
    end)
  end

  defp format_name(string) do
    string
    |> String.downcase()
    |> String.replace(" ", "_")
  end

  @spec check_frame_mapping(ContentType.t()) :: :ok | {:error, map() | String.t()}
  def check_frame_mapping(%ContentType{layout: %Layout{frame: nil}} = _content_type), do: :ok

  def check_frame_mapping(%ContentType{
        layout: %Layout{frame: %Frame{}},
        frame_mapping: nil
      }),
      do: {:error, "Frame mappings are missing"}

  def check_frame_mapping(%ContentType{
        fields: content_type_fields,
        frame_mapping: mappings,
        layout: %Layout{
          frame: %Frame{
            fields: frame_fields
          }
        }
      })
      when is_list(mappings) do
    frame_field_names =
      Enum.map(frame_fields, & &1["name"])

    content_type_field_names =
      Enum.map(content_type_fields, &format_name(&1.name))

    mapping_source_names = Enum.map(mappings, &format_name(&1["source"]))
    mapping_destination_names = Enum.map(mappings, & &1["destination"])

    missing_content_type_fields = mapping_source_names -- content_type_field_names
    missing_frame_fields = mapping_destination_names -- frame_field_names

    unmapped_frame_fields = frame_field_names -- mapping_destination_names

    cond do
      missing_content_type_fields == [] and missing_frame_fields == [] and
          unmapped_frame_fields == [] ->
        :ok

      unmapped_frame_fields != [] ->
        {:error, "Some frame fields are not mapped: #{Enum.join(unmapped_frame_fields, ", ")}"}

      true ->
        {:error,
         %{
           missing_content_type_fields: missing_content_type_fields,
           missing_frame_fields: missing_frame_fields
         }}
    end
  end
end
