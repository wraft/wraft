defmodule WraftDoc.Themes.ThemeAsset do
  @moduledoc """
    The Theme-asset association model.
  """
  use WraftDoc.Schema
  alias __MODULE__

  schema "theme_assets" do
    belongs_to(:asset, WraftDoc.Document.Asset)
    belongs_to(:theme, WraftDoc.Themes.Theme)

    timestamps()
  end

  # TODO include tests for the changeset
  def changeset(%ThemeAsset{} = theme_asset, attrs \\ %{}) do
    theme_asset
    |> cast(attrs, [:asset_id, :theme_id])
    |> validate_required([:asset_id, :theme_id])
  end
end
