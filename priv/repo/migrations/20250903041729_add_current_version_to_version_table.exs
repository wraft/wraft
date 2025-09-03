defmodule WraftDoc.Repo.Migrations.AddCurrentVersionToVersionTable do
  use Ecto.Migration

  def up do
    alter table(:version) do
      add(:current_version, :boolean, default: false)
    end
  end

  def down do
    alter table(:version) do
      remove(:current_version)
    end
  end
end
