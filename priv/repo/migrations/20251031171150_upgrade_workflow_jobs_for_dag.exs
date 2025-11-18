defmodule WraftDoc.Repo.Migrations.UpgradeWorkflowJobsForDag do
  use Ecto.Migration

  def change do
    alter table(:workflow_jobs) do
      # For React Flow visualization
      add(:position_x, :float)
      # For React Flow visualization
      add(:position_y, :float)
      # Keep order field for backward compatibility during migration
    end
  end
end
