defmodule WraftDoc.Repo.Migrations.CreateCloudImportAssets do
  use Ecto.Migration

  def change do
    create table(:cloud_import_assets) do
      add(:name, :string)
      add(:cloud_service, :string)
      add(:file_type, :string)
      add(:description, :text)
      add(:size, :bigint)
      add(:created_time, :utc_datetime)
      add(:modified_time, :utc_datetime)
      add(:owners, :map)
      add(:parents, {:array, :string})
      add(:file_extension, :string)

      timestamps()
    end
  end
end
