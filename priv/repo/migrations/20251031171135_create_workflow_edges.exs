defmodule WraftDoc.Repo.Migrations.CreateWorkflowEdges do
  use Ecto.Migration

  def change do
    create table(:workflow_edges, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:workflow_id, references(:workflows, type: :uuid, on_delete: :delete_all), null: false)

      # Source: either job or trigger (mutually exclusive)
      add(:source_job_id, references(:workflow_jobs, type: :uuid, on_delete: :delete_all))
      add(:source_trigger_id, references(:workflow_triggers, type: :uuid, on_delete: :delete_all))

      # Target: always a job
      add(:target_job_id, references(:workflow_jobs, type: :uuid, on_delete: :delete_all),
        null: false
      )

      # Conditional execution
      # "on_job_success", "on_job_failure", "always"
      add(:condition_type, :string, null: false)
      # For future js_expression support
      add(:condition_expression, :text)
      add(:condition_label, :string)
      add(:enabled, :boolean, default: true, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:workflow_edges, [:workflow_id]))
    create(index(:workflow_edges, [:source_job_id]))
    create(index(:workflow_edges, [:source_trigger_id]))
    create(index(:workflow_edges, [:target_job_id]))
    create(index(:workflow_edges, [:condition_type]))

    # Ensure source is either job or trigger, but not both
    create(
      constraint(:workflow_edges, :source_mutually_exclusive,
        check: "(source_job_id IS NULL) != (source_trigger_id IS NULL)"
      )
    )
  end
end
