defmodule WraftDoc.TemplateAssets.TemplateAsset do
  @moduledoc """
    The template asset model.
  """
  alias __MODULE__
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  schema "template_asset" do
    field(:name, :string)
    field(:zip_file, WraftDocWeb.TemplateAssetUploader.Type)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
  end

  def update_changeset(%TemplateAsset{} = template_asset, attrs \\ %{}) do
    template_asset
    |> cast(attrs, [:name])
    |> cast_attachments(attrs, [:zip_file])
    |> validate_required([:name, :zip_file])
  end

  def file_changeset(template_asset, attrs \\ %{}) do
    template_asset
    |> cast_attachments(attrs, [:zip_file])
    |> validate_required([:zip_file])
  end
end
