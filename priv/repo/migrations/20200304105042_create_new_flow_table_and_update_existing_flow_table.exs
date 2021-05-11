defmodule WraftDoc.Repo.Migrations.CreateNewFlowTableAndUpdateExistingFlowTable do
  use Ecto.Migration

  def up do
    rename(table(:flow), to: table(:state))

    create table(:flow, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all),
        null: false
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end

    alter table(:state) do
      add(:flow_id, references(:flow, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    drop(index(:state, [:organisation_id, :state], name: :flow_organisation_unique_index))
    create(unique_index(:state, [:state, :flow_id], name: :flow_state_unique_index))
    create(unique_index(:flow, [:name, :organisation_id], name: :flow_organisation_unique_index))
  end

  def down do
    alter table(:state) do
      remove(:flow_id)
    end

    drop_if_exists(table(:flow))

    rename(table(:state), to: table(:flow))
    create(unique_index(:flow, [:state, :organisation_id], name: :flow_organisation_unique_index))
  end
end
