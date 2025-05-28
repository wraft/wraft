defmodule WraftDoc.Repo.Migrations.CommentToText do
  use Ecto.Migration

  def up do
    alter table(:comment) do
      modify(:comment, :text, null: false)
      add(:state, :string, null: false, default: "active")
      add(:doc_version_id, :string, null: false, default: "0.0.0")
    end
  end

  def down do
    alter table(:comment) do
      modify(:comment, :string, null: false)
      remove(:state)
      remove(:doc_version_id)
    end
  end
end
