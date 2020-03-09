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
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
  end
end
