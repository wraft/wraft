defmodule WraftDoc.TemplateAssets.TemplateAsset do
  @moduledoc """
    The template asset model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias __MODULE__

  schema "template_asset" do
    field(:name, :string)
    field(:description, :string)
    field(:zip_file, WraftDocWeb.TemplateAssetUploader.Type)
    field(:thumbnail, WraftDocWeb.TemplateAssetThumbnailUploader.Type)
    field(:wraft_json, :map)
    field(:file_entries, {:array, :string})

    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [:name, :description, :organisation_id, :wraft_json, :file_entries])
    |> validate_required([:name])
  end

  def update_changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [:name, :description, :wraft_json, :file_entries])
    |> cast_attachments(attrs, [:zip_file, :thumbnail])
    |> validate_required([:name, :zip_file])
  end

  def file_changeset(template_asset, attrs \\ %{}) do
    template_asset
    |> cast_attachments(attrs, [:zip_file, :thumbnail])
    |> validate_required([:zip_file])
  end
end
