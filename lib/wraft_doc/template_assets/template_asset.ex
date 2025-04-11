defmodule WraftDoc.TemplateAssets.TemplateAsset do
  @moduledoc """
    The template asset model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias __MODULE__
  alias WraftDoc.Account.User
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Enterprise.Organisation

  schema "template_asset" do
    field(:name, :string)
    field(:description, :string)
    field(:zip_file_size, :string)
    field(:file_name, :string)
    field(:thumbnail, WraftDocWeb.TemplateAssetThumbnailUploader.Type)
    field(:wraft_json, :map)
    field(:file_entries, {:array, :string})
    field(:is_imported, :boolean, default: true)

    belongs_to(:asset, Asset)
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
      :zip_file_size,
      :file_name,
      :asset_id
    ])
    |> cast_attachments(attrs, [:thumbnail])
    |> validate_required([:name])
    |> unique_constraint(:file_name,
      name: :unique_public_template_file_name,
      message: "Template asset already added"
    )
  end

  def update_changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [
      :name,
      :description,
      :asset_id,
      :wraft_json,
      :file_entries,
      :zip_file_size,
      :file_name
    ])
    |> cast_attachments(attrs, [:thumbnail])
    |> validate_required([:name])
    |> unique_constraint(:file_name,
      name: :unique_public_template_file_name,
      message: "Template asset already added"
    )
  end
end
