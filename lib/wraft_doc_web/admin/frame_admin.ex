defmodule WraftDocWeb.Frames.FrameAdmin do
  @moduledoc """
  Admin panel for managing frames in Kaffy.
  """
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Multi
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

  def default_actions(_schema),
    do: [
      :new,
      :show,
      :delete
    ]

  def custom_index_query(_conn, _schema, query),
    do: from(r in query, preload: [:organisation, :asset])

  def custom_show_query(_conn, _schema, query), do: from(r in query, preload: [:asset])

  def create_changeset(schema, attrs), do: Frame.admin_changeset(schema, attrs)

  def update_changeset(schema, attrs), do: Frame.admin_changeset(schema, attrs)

  def insert(conn, changeset) do
    %{"file" => file} = params = conn.params["frame"]

    with :ok <- FileHelper.validate_frame_file(file),
         {:ok, metadata} <- FileHelper.get_file_metadata(file),
         {:ok, params} <- Frames.process_frame_params(Map.merge(params, metadata)),
         {:ok, %Frame{} = frame} <- insert_multi(params) do
      {:ok, frame}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} when is_list(reason) ->
        changeset
        |> attach_errors_to_changeset(reason)
        |> then(&{:error, &1})

      {:error, reason} ->
        {:error, {changeset, reason}}
    end
  end

  defp attach_errors_to_changeset(changeset, errors) do
    Enum.reduce(errors, changeset, fn %{message: message, type: type}, acc_changeset ->
      Ecto.Changeset.add_error(acc_changeset, :file, "#{type}: #{message}")
    end)
  end

  defp insert_multi(%{"frameType" => frame_type} = params) do
    Multi.new()
    |> Multi.run(:create_asset, fn _, _ ->
      Assets.create_asset(nil, Map.merge(params, %{"type" => "frame"}))
    end)
    |> Multi.run(:create_template_asset, fn _, %{create_asset: %Asset{id: asset_id}} ->
      Frames.create_frame(nil, Map.merge(params, %{"assets" => asset_id, "type" => frame_type}))
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_template_asset: template_asset}} ->
        {:ok, template_asset}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp get_organisations do
    Organisation
    |> where([o], o.name != "Personal")
    |> order_by(asc: :name)
    |> Repo.all()
    |> Enum.map(&{&1.name, &1.id})
  end
end
