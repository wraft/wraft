defmodule WraftDoc.Document.Block do
  @moduledoc """
    The block model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Block

  schema "block" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:btype, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Block{} = block, attrs \\ %{}) do
    block
    |> cast(attrs, [:name, :btype, :content_type_id, :organisation_id])
    |> validate_required([:name, :btype, :content_type_id, :organisation_id])
    |> unique_constraint(:name,
      message: "Block with same name exists.!",
      name: :block_content_type_unique_index
    )
  end
end
