defmodule WraftDoc.Repo.Migrations.CreateWorkflowRunLogs do
  use Ecto.Migration

  def change do
    create table(:workflow_run_logs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:run_id, references(:workflow_runs, type: :uuid, on_delete: :delete_all), null: false)
      add(:run_job_id, references(:workflow_run_jobs, type: :uuid, on_delete: :delete_all))
      add(:level, :string, null: false)
      add(:message, :text, null: false)
      add(:metadata, :map, default: %{})
      add(:timestamp, :utc_datetime, null: false)
    end

    create(index(:workflow_run_logs, [:run_id]))
    create(index(:workflow_run_logs, [:run_job_id]))
    create(index(:workflow_run_logs, [:run_id, :timestamp]))
    create(index(:workflow_run_logs, [:level]))
  end
end
