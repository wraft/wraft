defmodule WraftDoc.Document.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comment" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:comment, :string)
    field(:is_parent, :boolean)
    field(:master, :string)
    field(:master_id, :string)
    field(:replay_count, :integer)
    belongs_to(:parent, WraftDoc.Document.Comment)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(comment, attrs \\ %{}) do
    comment
    |> cast(attrs, [
      :comment,
      :is_parent,
      :master,
      :master_id,
      :parent_id,
      :user_id,
      :organisation_id
    ])
    |> validate_required([
      :comment,
      :is_parent,
      :master,
      :master_id,
      :user_id,
      :organisation_id
    ])
  end

  def replay_count_changeset(comment, attrs \\ %{}) do
    comment
    |> cast(attrs, [:replay_count])
    |> validate_required([:replay_count])
  end
end