defmodule WraftDoc.Document.ThemeAsset do
  @moduledoc """
    The Theme-asset association model.
  """
  use WraftDoc.Schema
  alias WraftDoc.Document.{Asset, Theme}
  alias __MODULE__

  schema "theme_assets" do
    belongs_to(:asset, Asset)
    belongs_to(:theme, Theme)

    timestamps()
  end

  # TODO include tests for the changeset
  def changeset(%ThemeAsset{} = theme_asset, attrs \\ %{}) do
    theme_asset
    |> cast(attrs, [:asset_id, :theme_id])
    |> validate_required([:asset_id, :theme_id])
  end
end
