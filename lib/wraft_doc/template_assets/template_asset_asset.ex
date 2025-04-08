defmodule WraftDoc.TemplateAssets.TemplateAssetAsset do
  @moduledoc """
    The template asset model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias WraftDoc.Assets.Asset
  alias WraftDoc.TemplateAssets.TemplateAsset

  schema "template_asset_asset" do
    belongs_to(:template_asset, TemplateAsset)
    belongs_to(:asset, Asset)

    timestamps()
  end

  def changeset(template_asset_asset, attrs \\ %{}) do
    template_asset_asset
    |> cast(attrs, [:template_asset_id, :asset_id])
    |> validate_required([:template_asset_id, :asset_id])
  end
end
