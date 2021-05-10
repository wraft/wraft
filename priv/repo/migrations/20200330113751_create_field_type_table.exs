defmodule WraftDoc.Repo.Migrations.CreateFieldTypeTable do
  use Ecto.Migration

  def up do
    create table(:field_type, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end

    create table(:content_type_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)

      add(
        :content_type_id,
        references(:content_type, type: :uuid, column: :id, on_delete: :delete_all)
      )

      add(
        :field_type_id,
        references(:field_type, type: :uuid, column: :id, on_delete: :delete_all)
      )

      timestamps()
    end

    alter table(:content_type) do
      remove(:fields)
    end

    create(unique_index(:field_type, [:name], name: :field_type_unique_index))
  end

  def down do
    alter table(:content_type) do
      add(:fields, :jsonb)
    end

    drop_if_exists(table(:content_type_field))
    drop_if_exists(table(:field_type))
  end
end
