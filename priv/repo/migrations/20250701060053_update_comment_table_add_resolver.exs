defmodule WraftDoc.Repo.Migrations.UpdateCommentTableAddResolver do
  use Ecto.Migration

  def up do
    alter table(:comment) do
      add(:resolved?, :boolean, default: false)
      add(:resolver_id, references(:user, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:comment) do
      remove(:resolved?)
      remove(:resolver_id)
    end
  end
end
