defmodule WraftDoc.Repo.Migrations.AddDataset do
  use Ecto.Migration

  def up do
    alter table(:block) do
      remove(:fields)
      add(:dataset, :jsonb)
    end
  end

  def down do
    alter table(:block) do
      add(:fields, :jsonb)
      remove(:dataset)
    end
  end
end
