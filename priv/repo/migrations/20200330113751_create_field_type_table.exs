defmodule WraftDoc.Repo.Migrations.CreateFieldTypeTable do
  use Ecto.Migration

  def up do
    create table(:field_type) do
      add(:uuid, :uuid, null: false)
      add(:name, :string, null: false)
      add(:creator_id, references(:user, on_delete: :nilify_all))

      timestamps()
    end

    create table(:content_type_field) do
      add(:uuid, :uuid, null: false)
      add(:name, :string, null: false)
      add(:content_type_id, references(:content_type, on_delete: :delete_all))
      add(:field_type_id, references(:field_type, on_delete: :delete_all))
      add(:creator_id, references(:user, on_delete: :nilify_all))

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
