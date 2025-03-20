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
      name: %{type: :text, required: true},
      description: %{type: :text},
      type: %{
        label: "Type",
        type: :choices,
        choices: [
          {"Typst", "typst"},
          {"Latex", "latex"}
        ],
        required: true
      },
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

  def insert(conn, _changeset) do
    params = conn.params["frame"]

    params
    |> Map.merge(%{"type" => "frame"})
    |> then(&Assets.create_asset(nil, &1))
    |> case do
      {:ok, %Asset{id: asset_id}} ->
        params
        |> Map.merge(%{"assets" => asset_id})
        |> then(&Frames.create_frame(nil, &1))
        |> case do
          {:ok, frame} -> {:ok, frame}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %Ecto.Changeset{data: %{assets: [asset | _]} = data}) do
    params = conn.params["frame"]

    asset
    |> Assets.update_asset(Map.merge(params, %{"type" => "frame"}))
    |> case do
      {:ok, %Asset{id: asset_id}} ->
        data
        |> Frames.update_frame(nil, Map.merge(params, %{"assets" => asset_id}))
        |> case do
          {:ok, frame} -> {:ok, frame}
          {:error, changeset} -> {:error, changeset}
        end

      {:error, changeset} ->
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
