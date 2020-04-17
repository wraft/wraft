defmodule WraftDoc.Document.BlockTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "block_template" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:title, :string)
    field(:body, :string)
    field(:serialised, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(block_template, attrs \\ %{}) do
    block_template
    |> cast(attrs, [:title, :body, :serialised, :creator_id])
    |> validate_required([:title, :body, :serialised, :creator_id])
  end
end
