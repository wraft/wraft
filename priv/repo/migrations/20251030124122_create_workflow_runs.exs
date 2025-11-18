defmodule WraftDoc.Repo.Migrations.CreateWorkflowRuns do
  use Ecto.Migration

  def change do
    create table(:workflow_runs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:workflow_id, references(:workflows, type: :uuid, on_delete: :delete_all), null: false)
      add(:trigger_id, references(:workflow_triggers, type: :uuid, on_delete: :nilify_all))
      add(:state, :string, null: false)
      add(:started_at, :utc_datetime)
      add(:completed_at, :utc_datetime)
      add(:duration_ms, :integer)
      add(:input_data, :map, default: %{})
      add(:output_data, :map)
      add(:error, :map)
      timestamps(type: :utc_datetime)
    end

    create(index(:workflow_runs, [:workflow_id]))
    create(index(:workflow_runs, [:workflow_id, :state]))
    create(index(:workflow_runs, [:workflow_id, :inserted_at]))
    create(index(:workflow_runs, [:state]))
    create(index(:workflow_runs, [:inserted_at]))

    create(
      index(:workflow_runs, [:workflow_id, :state, :inserted_at],
        name: :workflow_runs_workflow_state_time_idx
      )
    )
  end
end
