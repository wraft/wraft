defmodule WraftDocWeb.Frames.FrameAdmin do
  @moduledoc """
  Admin panel for managing frames in Kaffy.
  """
  use Ecto.Schema
  import Ecto.Query

  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame
  alias WraftDoc.Repo
  alias WraftDoc.Utils.FileHelper

  def index(_) do
    [
      name: %{label: "Name", type: :string},
      description: %{label: "Description", type: :string},
      file_size: %{name: "File size", type: :string},
      organisation: %{name: "Organisation", value: fn %{organisation: %{name: name}} -> name end},
      inserted_at: %{name: "Created At", type: :datetime},
      updated_at: %{label: "Updated At", type: :datetime}
    ]
  end

  def form_fields(_) do
    [
      file: %{
        type: :file,
        required: true
      },
      thumbnail: %{
        type: :file,
        required: false
      },
      organisation_id: %{
        label: "Organisations",
        type: :choices,
        choices: get_organisations(),
        required: true,
        help_text: "Select organisation to which this plan will be applied."
      }
    ]
  end

  def custom_index_query(_conn, _schema, query),
    do: from(r in query, preload: [:organisation, :assets])

  def custom_show_query(_conn, _schema, query), do: from(r in query, preload: [:assets])

  def create_changeset(schema, attrs), do: Frame.admin_changeset(schema, attrs)

  def update_changeset(schema, attrs), do: Frame.admin_changeset(schema, attrs)

  def insert(conn, changeset) do
    %{"file" => %{path: file_path}} = params = conn.params["frame"]

    with :ok <- FileHelper.validate_frame_file(file_path),
         {:ok, params} <- process_file_and_params(params),
         {:ok, %Asset{id: asset_id}} <-
           Assets.create_asset(nil, Map.merge(params, %{"type" => "frame"})),
         {:ok, frame} <- Frames.create_frame(nil, Map.merge(params, %{"assets" => asset_id})) do
      {:ok, frame}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> {:error, {changeset, reason}}
    end
  end

  def update(conn, %Ecto.Changeset{data: %{assets: asset} = data} = changeset) do
    %{"file" => %{path: file_path}} = params = conn.params["frame"]

    with :ok <- FileHelper.validate_frame_file(file_path),
         {:ok, params} <- process_file_and_params(params),
         {:ok, %Asset{id: asset_id}} <-
           Assets.update_asset(asset, Map.merge(params, %{"type" => "frame"})),
         {:ok, frame} <-
           Frames.update_frame(data, nil, Map.merge(params, %{"assets" => asset_id})) do
      {:ok, frame}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> {:error, {changeset, reason}}
    end
  end

  defp process_file_and_params(%{"file" => %{path: file_path}} = params) do
    file_path
    |> File.read!()
    |> Frames.process_frame_params(params)
  end

  defp get_organisations do
    Organisation
    |> where([o], o.name != "Personal")
    |> order_by(asc: :name)
    |> Repo.all()
    |> Enum.map(&{&1.name, &1.id})
  end
end
