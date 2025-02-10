defmodule WraftDoc.Repo.Migrations.AddTypeAndHybridVersioningToInstanceVersion do
  use Ecto.Migration

  def up do
    alter table(:version) do
      add(:type, :string)
    end

    execute("UPDATE version SET type = 'build' WHERE type IS NULL")
  end

  def down do
    alter table(:version) do
      remove(:type)
    end
  end
end
