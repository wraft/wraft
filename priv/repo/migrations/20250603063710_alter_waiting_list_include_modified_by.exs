defmodule WraftDoc.Repo.Migrations.AlterWaitingListIncludeModifiedBy do
  use Ecto.Migration

  def up do
    alter table(:waiting_list) do
      add(:modified_by_id, references(:internal_user, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:waiting_list) do
      remove(:modified_by_id)
    end
  end
end
