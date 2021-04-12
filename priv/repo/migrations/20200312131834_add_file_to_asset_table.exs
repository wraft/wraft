defmodule WraftDoc.Repo.Migrations.AddFileToAssetTable do
  use Ecto.Migration

  def up do
    alter table(:asset) do
      add(:file, :string)
    end
  end

  def down do
    alter table(:asset) do
      remove(:file)
    end
  end
end
