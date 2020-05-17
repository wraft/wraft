defmodule WraftDoc.Repo.Migrations.AddTypeColumnToInstanceTable do
  use Ecto.Migration

  def up do
    alter table(:content) do
      add(:type, :integer)
    end
  end

  def down do
    alter table(:content) do
      remove(:type)
    end
  end
end
