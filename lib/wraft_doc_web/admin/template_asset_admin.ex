defmodule WraftDocWeb.TemplateAssets.TemplateAssetAdmin do
  @moduledoc """
  Admin panel configuration for managing template assets in Kaffy.
  """
  use Waffle.Ecto.Schema

  import Ecto.Query

  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDocWeb.TemplateAssetThumbnailUploader
  alias WraftDocWeb.TemplateAssetUploader

  def index(_) do
    [
      name: %{label: "Name", type: :string},
      inserted_at: %{label: "Created At", type: :datetime},
      updated_at: %{label: "Updated At", type: :datetime}
    ]
  end

  def custom_index_query(_conn, _resource, query) do
    from(t in query,
      where: is_nil(t.organisation_id) and is_nil(t.creator_id)
    )
  end

  def form_fields(_) do
    [
      name: %{type: :text, required: true},
      zip_file: %{
        type: :file,
        required: true
      },
      thumbnail: %{
        type: :file,
        required: false
      }
    ]
  end

  defp admin_changeset(%{"zip_file" => %{filename: zip_file_name}} = params) do
    %TemplateAsset{}
    |> Map.merge(%{:zip_file_name => zip_file_name})
    |> TemplateAsset.changeset(params)
    |> then(&{:ok, &1})
  end

  def before_insert(conn, changeset) do
    params = conn.params["template_asset"]

    with :ok <- check_zip_exists(params),
         {:ok, params, _} <-
           TemplateAssets.process_template_asset(params, :file, params["zip_file"]),
         {:ok, changeset} <- admin_changeset(params) do
      {:ok, changeset}
    else
      {:error, error_message} ->
        custom_error(changeset, error_message)
    end
  end

  def admin_file_changeset(schema, params) do
    cast_attachments(schema, params, [:zip_file, :thumbnail])
  end

  defp custom_error(changeset, error_message) do
    changeset
    |> Ecto.Changeset.add_error(:zip_file, error_message)
    |> then(&{:error, &1})
  end

  defp check_zip_exists(%{"zip_file" => %Plug.Upload{filename: filename}}) do
    if Path.extname(filename) == ".zip" do
      :ok
    else
      {:error, "is not valid"}
    end
  end

  defp check_zip_exists(_params) do
    {:error, "not provided."}
  end

  def after_insert(conn, template_asset) do
    params = conn.params["template_asset"] || %{}

    template_asset
    |> admin_file_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, updated_template_asset} ->
        {:ok, updated_template_asset}

      {:error, error_changeset} ->
        {:error, error_changeset}
    end
  end

  def after_delete(_conn, %{zip_file: zip_file, thumbnail: thumbnail} = template_asset) do
    with template_asset <- Map.put(template_asset, :zip_file_name, zip_file.file_name),
         :ok <- TemplateAssetUploader.delete({zip_file, template_asset}),
         :ok <- TemplateAssetThumbnailUploader.delete({thumbnail, template_asset}) do
      {:ok, template_asset}
    end
  end
end
