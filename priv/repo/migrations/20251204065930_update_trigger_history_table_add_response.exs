defmodule WraftDoc.Repo.Migrations.UpdateTriggerHistoryTableAddResponse do
  use Ecto.Migration

  def up do
    alter table(:trigger_history) do
      add(:response, :map)
    end
  end

  def down do
    alter table(:trigger_history) do
      remove(:response)
    end
  end
end
