defmodule WraftDoc.Repo.Migrations.AddMissingFields do
  use Ecto.Migration

  def up do
    alter table(:content_type) do
      modify(:fields, :jsonb, null: false)
      timestamps()
    end

    rename(table(:content), :seralized, to: :serialized)

    alter table(:content) do
      modify(:serialized, :jsonb, null: false)
    end

    alter table(:theme) do
      modify(:typescale, :jsonb, null: false)
    end

    alter table(:asset) do
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:content_type) do
      modify(:fields, :jsonb)
      remove(:inserted_at)
      remove(:updated_at)
    end

    alter table(:content_type) do
      modify(:fields, :jsonb)
    end

    rename(table(:content), :serialized, to: :seralized)

    alter table(:content) do
      modify(:seralized, :jsonb)
    end

    alter table(:theme) do
      modify(:typescale, :jsonb)
    end

    alter table(:asset) do
      remove(:creator_id)
    end
  end
end
