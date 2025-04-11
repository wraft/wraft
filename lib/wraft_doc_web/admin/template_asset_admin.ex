defmodule WraftDocWeb.TemplateAssets.TemplateAssetAdmin do
  @moduledoc """
  Admin panel configuration for managing template assets in Kaffy.
  """
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDoc.Utils.FileValidator
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

  def default_actions(_schema),
    do: [
      :new,
      :show,
      :delete
    ]

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

  def insert(
        %{
          params: %{
            "template_asset" =>
              %{"file" => %{filename: file_name, path: file_path} = file} = params
          }
        },
        changeset
      ) do
    params =
      Map.put(params, "type", "zip")

    with :ok <- check_zip_exists(params),
         {:ok, _} <- FileValidator.validate_file(file_path),
         :ok <- TemplateAssets.validate_template_asset_file(file),
         {:ok, params, _} <-
           TemplateAssets.process_template_asset(params, :file, file),
         {:ok, %TemplateAsset{} = template_asset} <-
           insert_multi(params, file_name) do
      {:ok, template_asset}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> {:error, {changeset, reason}}
    end
  end

  defp insert_multi(params, file_name) do
    Multi.new()
    |> Multi.run(:create_asset, fn _, _ ->
      Assets.create_asset(nil, params)
    end)
    |> Multi.run(:create_template_asset, fn _, %{create_asset: %Asset{id: asset_id}} ->
      TemplateAssets.create_template_asset(
        nil,
        Map.merge(params, %{"asset_id" => asset_id, "file_name" => file_name})
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_template_asset: template_asset}} ->
        {:ok, template_asset}

      {:error, _, changeset, _} ->
        {:error, changeset}
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
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, changeset}
      {:error, reason} -> {:error, {changeset, reason}}
    end
  end

  defp delete_thumbnail(%{thumbnail: thumbnail} = template_asset) when thumbnail != nil,
    do: TemplateAssetThumbnailUploader.delete({thumbnail, template_asset})

  defp delete_thumbnail(_), do: :ok
end
