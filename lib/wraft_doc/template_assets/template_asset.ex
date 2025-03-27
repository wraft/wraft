defmodule WraftDoc.TemplateAssets.TemplateAsset do
  @moduledoc """
    The template asset model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias __MODULE__
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.TemplateAssets.TempAsset

  schema "template_asset" do
    field(:name, :string)
    field(:description, :string)
    field(:zip_file, WraftDocWeb.TemplateAssetUploader.Type)
    field(:zip_file_size, :string)
    field(:thumbnail, WraftDocWeb.TemplateAssetThumbnailUploader.Type)
    field(:wraft_json, :map)
    field(:file_entries, {:array, :string})
    field(:is_imported, :boolean, default: true)

    has_one(:temp_asset, TempAsset)
    has_one(:asset, through: [:temp_asset, :asset])

    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)

    timestamps()
  end

  def changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [
      :name,
      :description,
      :organisation_id,
      :wraft_json,
      :file_entries,
      :zip_file_size
    ])
    |> validate_required([:name])
  end

  def update_changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [:name, :description, :wraft_json, :file_entries, :zip_file_size])
    |> cast_attachments(attrs, [:zip_file, :thumbnail])
    |> validate_required([:name])
    |> add_zip_file_size(attrs)
  end

  def file_changeset(template_asset, attrs \\ %{}) do
    template_asset
    |> cast_attachments(attrs, [:zip_file, :thumbnail])
    |> add_zip_file_size(attrs)
  end

  def add_zip_file_size(changeset, %{"zip_file" => file}) do
    file.path
    |> File.stat!()
    |> Map.get(:size)
    |> Sizeable.filesize()
    |> then(&put_change(changeset, :zip_file_size, &1))
  end

  def add_zip_file_size(changeset, _), do: changeset
end
