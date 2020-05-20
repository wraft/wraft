defmodule WraftDoc.Repo.Migrations.AddDurationStartAndEndTimeColumnsToTriggerHistoryTable do
  use Ecto.Migration

  def up do
    rename(table(:trigger_history), :meta, to: :error)

    alter table(:trigger_history) do
      add(:start_time, :naive_datetime)
      add(:end_time, :naive_datetime)
      add(:duration, :integer)
    end
  end

  def down do
    alter table(:trigger_history) do
      remove(:start_time)
      remove(:end_time)
      remove(:duration)
    end

    rename(table(:trigger_history), :error, to: :meta)
  end
end
