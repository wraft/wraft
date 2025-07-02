defmodule WraftDoc.Repo.Migrations.UpdateCommentTableAddResolver do
  use Ecto.Migration

  def up do
    alter table(:comment) do
      remove(:doc_version_id)
      add(:resolved?, :boolean, default: false)
      add(:resolver_id, references(:user, type: :uuid, on_delete: :nilify_all))
      add(:doc_version_id, references(:version, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:comment) do
      remove(:doc_version_id)
      remove(:resolved?)
      remove(:resolver_id)
      add(:doc_version_id, :string, null: false, default: "0.0.0")
    end
  end
end
