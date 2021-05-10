defmodule WraftDoc.Repo.Migrations.CreateContentTypeAndAssociatedTables do
  use Ecto.Migration

  def up do
    create table(:content_type) do
      add(:uuid, :uuid, null: false)
      add(:name, :string, null: false)
      add(:description, :string)
      add(:fields, :jsonb)
      add(:layout_id, references(:layout))
      add(:creator_id, references(:user))
      add(:organisation_id, references(:organisation))
    end

    create table(:content) do
      add(:uuid, :uuid, null: false)
      add(:instance_id, :string, null: false)
      add(:raw, :text)
      add(:seralized, :jsonb)
      add(:creator_id, references(:user))
      add(:content_type_id, references(:content_type))
      timestamps()
    end

    create table(:block, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:description, :string)
      add(:btype, :string)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :content_type_id,
        references(:content_type, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end

    create table(:theme) do
      add(:uuid, :uuid, null: false)
      add(:name, :string, null: false)
      add(:font, :string)
      add(:typescale, :jsonb)
      add(:file, :string)
      add(:creator_id, references(:user))
      add(:organisation_id, references(:organisation))
      timestamps()
    end

    create table(:flow) do
      add(:uuid, :uuid, null: false)
      add(:state, :string, null: false)
      add(:order, :integer, null: false)
      add(:creator_id, references(:user))
      add(:organisation_id, references(:organisation))
      timestamps()
    end

    create(
      unique_index(:content_type, [:name, :organisation_id],
        name: :content_type_organisation_unique_index
      )
    )

    create(
      unique_index(:content, [:instance_id, :content_type_id],
        name: :content_organisation_unique_index
      )
    )

    create(
      unique_index(:block, [:name, :content_type_id], name: :block_content_type_unique_index)
    )

    create(unique_index(:flow, [:state, :organisation_id], name: :flow_organisation_unique_index))
  end

  def down do
    drop_if_exists(table(:flow))
    drop_if_exists(table(:theme))
    drop_if_exists(table(:block))
    drop_if_exists(table(:content))
    drop_if_exists(table(:content_type))
  end
end
