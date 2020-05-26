defmodule WraftDoc.Repo.Migrations.AddMetaColumnToDataTemplateTable do
  use Ecto.Migration

  def up do
    alter table(:data_template) do
      add(:serialized, :jsonb)
    end
  end

  def down do
    alter table(:data_template) do
      remove(:serialized)
    end
  end
end
