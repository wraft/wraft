defmodule WraftDoc.Document.BlockTemplate do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias WraftDoc.{Account.User}
  import Ecto.Query

  defimpl Spur.Trackable, for: BlockTemplate do
    def actor(block_template), do: "#{block_template.creator_id}"
    def object(block_template), do: "BlockTemplate:#{block_template.id}"
    def target(_chore), do: nil

    def audience(%{creator_id: id}) do
      from(u in User,
        join: us in User,
        where: us.id == ^id,
        where: u.organisation_id == us.organisation_id
      )
    end
  end

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
