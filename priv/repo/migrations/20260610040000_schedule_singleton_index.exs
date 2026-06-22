defmodule WraftDoc.Repo.Migrations.ScheduleSingletonIndex do
  use Ecto.Migration

  # system_backup_schedule is a singleton (one row). Enforce it at the DB
  # level over a constant expression so two concurrent get_schedule/0 callers
  # (e.g. the 15-min checker + an admin page load) can't insert two rows.
  def change do
    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS system_backup_schedule_singleton_idx " <>
        "ON system_backup_schedule ((true))",
      "DROP INDEX IF EXISTS system_backup_schedule_singleton_idx"
    )
  end
end
