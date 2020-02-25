defmodule WraftDoc.Document.LayoutAsset do
  @moduledoc """
    The layout-asset association model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.LayoutAsset

  schema "layout_asset" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    belongs_to(:layout, WraftDoc.Document.Layout)
    belongs_to(:asset, WraftDoc.Document.Asset)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%LayoutAsset{} = layout_asset, attrs \\ %{}) do
    layout_asset
    |> cast(attrs, [:layout_id, :asset_id])
  end
end
