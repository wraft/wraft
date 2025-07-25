defmodule WraftDoc.Themes.FontAsset do
  @moduledoc """
    Module for managing font assets.
  """
  use WraftDoc.Schema

  alias __MODULE__

  schema "font_assets" do
    belongs_to(:asset, WraftDoc.Assets.Asset)
    belongs_to(:font, WraftDoc.Themes.Font)

    timestamps()
  end

  def changeset(%FontAsset{} = font_asset, attrs \\ %{}) do
    font_asset
    |> cast(attrs, [:asset_id, :font_id])
    |> validate_required([:asset_id, :font_id])
  end
end
