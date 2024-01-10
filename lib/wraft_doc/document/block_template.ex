defmodule WraftDoc.Document.BlockTemplate do
  @moduledoc false
  use WraftDoc.Schema

  schema "block_template" do
    field(:title, :string)
    field(:body, :string)
    field(:serialized, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(block_template, attrs \\ %{}) do
    block_template
    |> cast(attrs, [:title, :body, :serialized, :organisation_id, :creator_id])
    |> validate_required([:title, :body, :serialized, :organisation_id, :creator_id])
    |> unique_constraint(:title,
      message: "A block template with the same name exists.!",
      name: :organisation_block_template_unique_index
    )
  end

  def update_changeset(block_template, attrs \\ %{}) do
    block_template
    |> cast(attrs, [:title, :body, :serialized])
    |> validate_required([:title, :body, :serialized])
    |> unique_constraint(:title,
      message: "A block template with the same name exists.!",
      name: :organisation_block_template_unique_index
    )
  end
end
