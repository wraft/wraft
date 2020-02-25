defmodule WraftDoc.Document.Asset do
  @moduledoc """
    The asset model.
  """
  alias WraftDoc.Document.Asset
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    timestamps()
  end

  def changeset(%Asset{} = asset, attrs \\ %{}) do
    asset |> cast(attrs, [:name]) |> validate_required([:name])
  end
end
