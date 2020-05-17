defmodule WraftDoc.Repo.Migrations.AddCreatorIdToHookTriggerHistoryTable do
  use Ecto.Migration

  def up do
    alter table(:hook_trigger_history) do
      add(:creator_id, references(:user, on_delete: :nilify_all))
      add(:state, :integer)
    end

    rename(table(:hook_trigger_history), to: table(:trigger_history))
  end

  def down do
    rename(table(:trigger_history), to: table(:hook_trigger_history))

    alter table(:hook_trigger_history) do
      remove(:creator_id)
      remove(:state)
    end
  end
end
