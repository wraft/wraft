defmodule WraftDoc.TemplateAssets.TempAsset do
  @moduledoc """
    The template asset model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  alias WraftDoc.Assets.Asset
  alias WraftDoc.TemplateAssets.TemplateAsset

  schema "temp_asset" do
    belongs_to(:template_asset, TemplateAsset)
    belongs_to(:asset, Asset)

    timestamps()
  end

  def changeset(temp_asset, attrs \\ %{}) do
    temp_asset
    |> cast(attrs, [:template_asset_id, :asset_id])
    |> validate_required([:template_asset_id, :asset_id])
  end
end
