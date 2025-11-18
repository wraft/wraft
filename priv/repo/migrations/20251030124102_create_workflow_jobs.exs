defmodule WraftDoc.Repo.Migrations.CreateWorkflowJobs do
  use Ecto.Migration

  def change do
    create table(:workflow_jobs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:workflow_id, references(:workflows, type: :uuid, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:order, :integer, null: false)
      add(:adaptor, :string, null: false)
      add(:config, :map, default: %{})
      add(:condition, :map)
      add(:credentials_id, references(:workflow_credentials, type: :uuid, on_delete: :nilify_all))
      timestamps(type: :utc_datetime)
    end

    create(index(:workflow_jobs, [:workflow_id]))
    create(index(:workflow_jobs, [:workflow_id, :order]))

    create(
      unique_index(:workflow_jobs, [:workflow_id, :order], name: :workflow_jobs_unique_order)
    )
  end
end
