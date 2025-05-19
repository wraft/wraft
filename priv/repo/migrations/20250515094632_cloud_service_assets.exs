defmodule WraftDoc.Repo.Migrations.CloudServiceAssets do
  use Ecto.Migration

  def change do
    create table(:cloud_service_assets) do
      add(:google_drive_id, :string, null: false)
      add(:name, :string)
      add(:mime_type, :string)
      add(:description, :text)
      add(:size, :bigint)
      add(:created_time, :utc_datetime)
      add(:modified_time, :utc_datetime)
      add(:owners, :map)
      add(:parents, {:array, :string})
      add(:file_extension, :string)

      timestamps()
    end

    create(unique_index(:cloud_service_assets, [:google_drive_id]))
  end
end
