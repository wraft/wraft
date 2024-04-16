defmodule WraftDoc.Repo.Migrations.UniqueIndexForOrderFlowId do
  use Ecto.Migration

  def change do
    create(unique_index(:state, [:order, :flow_id]))
  end
end
