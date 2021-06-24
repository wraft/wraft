defmodule WraftDoc.Repo.Migrations.CreateRoleGroup do
  use Ecto.Migration

  def change do
    create table(:role_group, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:description, :string)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create table(:group_role, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:group_id, references(:group, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:role_id, references(:role, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
