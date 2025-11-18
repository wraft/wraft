defmodule WraftDoc.Repo.Migrations.AddPositionsToWorkflows do
  use Ecto.Migration

  def change do
    alter table(:workflows) do
      # React Flow positions for visualization
      add(:positions, :map)
    end
  end
end
