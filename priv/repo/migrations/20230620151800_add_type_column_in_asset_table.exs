defmodule WraftDoc.Repo.Migrations.AddTypeColumnInAssetTable do
  use Ecto.Migration

  def change do
    alter table(:asset) do
      add(:type, :string)
    end
  end
end
