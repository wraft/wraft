defmodule WraftDoc.Repo.Migrations.AddTypeForState do
  use Ecto.Migration

  def up do
    alter table(:state) do
      add(:type, :string)
    end

    execute("UPDATE state SET type = 'editor' WHERE type IS NULL")
  end

  def down do
    alter table(:state) do
      remove(:type)
    end
  end
end
