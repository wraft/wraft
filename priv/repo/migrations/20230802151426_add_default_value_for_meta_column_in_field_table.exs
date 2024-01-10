defmodule WraftDoc.Repo.Migrations.AddDefaultValueForMetaColumnInFieldTable do
  use Ecto.Migration

  def up do
    alter table(:field) do
      # Removing the field so we can add the default values to all existing rows
      remove(:meta)
      add(:meta, :map, default: %{})
    end
  end

  def down do
    alter table(:field) do
      remove(:meta)
      add(:meta, :jsonb)
    end
  end
end
