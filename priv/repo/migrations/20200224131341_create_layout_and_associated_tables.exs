defmodule WraftDoc.Repo.Migrations.CreateLayoutAndAssociatedTables do
  use Ecto.Migration

  def up do
    create table(:slug, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end

    create table(:engine, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:api_route, :string)
      timestamps()
    end

    create table(:layout, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:description, :string)
      add(:width, :float)
      add(:height, :float)
      add(:unit, :string)
      add(:slug_id, references(:slug, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:engine_id, references(:engine, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create table(:asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)

      timestamps()
    end

    create table(:layout_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:layout_id, references(:layout, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end

    create(unique_index(:layout, :name, name: :layout_name_unique_index))
    create(unique_index(:slug, :name, name: :slug_name_unique_index))
  end

  def down do
    drop_if_exists(table(:layout_asset))
    drop_if_exists(table(:asset))
    drop_if_exists(table(:layout))
    drop_if_exists(table(:engine))
    drop_if_exists(table(:slug))
  end
end
