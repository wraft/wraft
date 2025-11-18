defmodule WraftDoc.Repo.Migrations.CreateWorkflowRunJobs do
  use Ecto.Migration

  def change do
    create table(:workflow_run_jobs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:run_id, references(:workflow_runs, type: :uuid, on_delete: :delete_all), null: false)
      add(:job_id, references(:workflow_jobs, type: :uuid, on_delete: :restrict), null: false)
      add(:state, :string, null: false)
      add(:started_at, :utc_datetime)
      add(:completed_at, :utc_datetime)
      add(:duration_ms, :integer)
      add(:input_data, :map, default: %{})
      add(:output_data, :map)
      add(:error, :map)
      add(:retry_count, :integer, default: 0)
      timestamps(type: :utc_datetime)
    end

    create(index(:workflow_run_jobs, [:run_id]))
    create(index(:workflow_run_jobs, [:run_id, :state]))
    create(index(:workflow_run_jobs, [:job_id]))
  end
end
