defmodule WraftDocWeb.TemplateAssets.TemplateAssetAdmin do
  @moduledoc """
  Admin panel configuration for managing template assets in Kaffy.
  """
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Query

  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDocWeb.AssetUploader
  alias WraftDocWeb.TemplateAssetThumbnailUploader

  def index(_) do
    [
      name: %{label: "Name", type: :string},
      description: %{label: "Description", type: :string},
      zip_file_size: %{name: "Zip size", type: :string},
      file: %{
        name: "File",
        type: :string,
        value: fn x ->
          x.file_name
        end
      },
      inserted_at: %{name: "Created At", type: :datetime},
      updated_at: %{label: "Updated At", type: :datetime}
    ]
  end

  def custom_index_query(_conn, _resource, query) do
    from(t in query,
      where: is_nil(t.organisation_id) and is_nil(t.creator_id),
      preload: [:asset]
    )
  end

  def custom_show_query(_conn, _resource, query) do
    from(t in query,
      preload: [:asset]
    )
  end

  def form_fields(_) do
    [
      name: %{type: :text, required: true},
      description: %{type: :text},
      file: %{
        type: :file,
        required: true
      },
      thumbnail: %{
        type: :file,
        required: false
      }
    ]
  end

  def insert(conn, _changeset) do
    params =
      Map.put(conn.params["template_asset"], "type", "template_asset")

    with :ok <- check_zip_exists(params),
         {:ok, params, _} <-
           TemplateAssets.process_template_asset(params, :raw_file, params["file"]),
         {:ok, %Asset{id: asset_id}} <- Assets.create_asset(nil, params),
         {:ok, %TemplateAsset{} = template_asset} <-
           TemplateAssets.create_template_asset(nil, Map.merge(params, %{"asset_id" => asset_id})) do
      {:ok, template_asset}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp check_zip_exists(%{"file" => %Plug.Upload{filename: filename}}) do
    if Path.extname(filename) == ".zip" do
      :ok
    else
      {:error, "File is invalid"}
    end
  end

  defp check_zip_exists(_params), do: {:error, "File not provided."}

  def before_delete(_conn, changeset) do
    %{asset: %{file: file} = asset} =
      template_asset = Repo.preload(changeset.data, [:asset])

    with {:ok, _} <- Assets.delete_asset(asset),
         :ok <- delete_thumbnail(template_asset),
         :ok <- AssetUploader.delete({file, asset}) do
      {:ok, changeset}
    end
  end

  defp delete_thumbnail(%{thumbnail: thumbnail} = template_asset) when thumbnail != nil,
    do: TemplateAssetThumbnailUploader.delete({thumbnail, template_asset})

  defp delete_thumbnail(_), do: :ok
end
