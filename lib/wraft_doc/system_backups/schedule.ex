defmodule WraftDoc.SystemBackups.Schedule do
  @moduledoc """
  Singleton row holding the UI-configurable auto-backup schedule. An
  hourly checker reads it and enqueues a scheduled backup when due, so
  enable/disable and timing changes take effect without a redeploy.
  """
  use WraftDoc.Schema

  schema "system_backup_schedule" do
    field(:enabled, :boolean, default: false)
    field(:frequency, Ecto.Enum, values: [:daily, :weekly], default: :daily)
    field(:hour, :integer, default: 1)
    field(:minute, :integer, default: 30)
    # 1 (Mon) .. 7 (Sun); used only for :weekly.
    field(:day_of_week, :integer, default: 1)
    field(:retention_count, :integer, default: 7)
    # Minimum minutes between manual backups; 0 = no limit.
    field(:manual_cooldown_minutes, :integer, default: 0)
    field(:last_run_on, :date)

    timestamps()
  end

  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [
      :enabled,
      :frequency,
      :hour,
      :minute,
      :day_of_week,
      :retention_count,
      :manual_cooldown_minutes
    ])
    |> validate_inclusion(:hour, 0..23)
    |> validate_inclusion(:minute, 0..59)
    |> validate_inclusion(:day_of_week, 1..7)
    |> validate_number(:retention_count, greater_than: 0, less_than_or_equal_to: 365)
    |> validate_number(:manual_cooldown_minutes, greater_than_or_equal_to: 0)
  end

  def run_changeset(schedule, date) do
    cast(schedule, %{last_run_on: date}, [:last_run_on])
  end
end
