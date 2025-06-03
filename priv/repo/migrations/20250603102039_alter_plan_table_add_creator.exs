defmodule WraftDoc.Repo.Migrations.AlterPlanTableAddCreator do
  use Ecto.Migration

  def up do
    alter table(:plan) do
      add(:creator_id, references(:internal_user, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:plan) do
      remove(:creator_id)
    end
  end
end
