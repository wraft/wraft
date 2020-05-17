defmodule WraftDoc.Repo.Migrations.AddDataColumnToTriggerHistoryTable do
  use Ecto.Migration

  def up do
    alter table(:trigger_history) do
      add(:data, :jsonb)
    end
  end

  def down do
    alter table(:trigger_history) do
      remove(:data)
    end
  end
end
