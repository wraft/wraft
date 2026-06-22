defmodule WraftDoc.Repo.Migrations.AddManualCooldownToSchedule do
  use Ecto.Migration

  def change do
    # Minimum minutes between manual backups. 0 = no limit (default) — the
    # single-in-flight index already prevents concurrent backups, so a
    # cooldown is optional abuse protection, configurable from the UI.
    alter table(:system_backup_schedule) do
      add(:manual_cooldown_minutes, :integer, null: false, default: 0)
    end
  end
end
