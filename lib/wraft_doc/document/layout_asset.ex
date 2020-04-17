defmodule WraftDoc.Document.LayoutAsset do
  @moduledoc """
    The layout-asset association model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias WraftDoc.{Document.Layout, Account.User}

  defimpl Spur.Trackable, for: LayoutAsset do
    def actor(layout_asset), do: "#{layout_asset.creator_id}"
    def object(layout_asset), do: "LayoutAsset:#{layout_asset.id}"
    def target(_chore), do: nil

    def audience(%{layout_id: id}) do
      from(u in User,
        join: l in Layout,
        where: l.id == ^id,
        where: u.organisation_id == l.organisation_id
      )
    end
  end

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
    |> unique_constraint(:layout_id,
      message: "Asset already added.!",
      name: :layout_asset_unique_index
    )
  end
end
