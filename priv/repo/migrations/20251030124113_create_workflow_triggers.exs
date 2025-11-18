defmodule WraftDoc.Repo.Migrations.CreateWorkflowTriggers do
  use Ecto.Migration

  def change do
    create table(:workflow_triggers, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:workflow_id, references(:workflows, type: :uuid, on_delete: :delete_all), null: false)
      add(:type, :string, null: false)
      add(:is_active, :boolean, default: true, null: false)
      add(:config, :map, default: %{})
      add(:secret, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:workflow_triggers, [:workflow_id]))
    create(index(:workflow_triggers, [:type, :is_active]))
    create(index(:workflow_triggers, [:secret]))
  end
end
