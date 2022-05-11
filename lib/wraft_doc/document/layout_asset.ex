defmodule WraftDoc.Document.LayoutAsset do
  @moduledoc """
    The layout-asset association model.
  """
  use WraftDoc.Schema
  alias __MODULE__

  schema "layout_asset" do
    belongs_to(:layout, WraftDoc.Document.Layout)
    belongs_to(:asset, WraftDoc.Document.Asset)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%LayoutAsset{} = layout_asset, attrs \\ %{}) do
    layout_asset
    |> cast(attrs, [:layout_id, :asset_id])
    |> validate_required([:layout_id, :asset_id])
    |> unique_constraint(:layout_id,
      message: "Asset already added.!",
      name: :layout_asset_unique_index
    )
  end
end
