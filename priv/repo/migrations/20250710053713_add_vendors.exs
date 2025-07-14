defmodule WraftDoc.Repo.Migrations.MigrateVendorAndAddVendorContacts do
  use Ecto.Migration

  def up do
    # Rename the table from vendor to vendors
    rename(table(:vendor), to: table(:vendors))

    # Add new columns
    alter table(:vendors) do
      add(:city, :string)
      add(:country, :string)
      add(:website, :string)
      remove(:gstin, :string)
    end

    # Add unique index on organisation_id and name
    create(unique_index(:vendors, [:organisation_id, :name]))

    create table(:vendor_contacts, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:email, :string)
      add(:phone, :string)
      add(:job_title, :string)
      add(:vendor_id, references(:vendors, type: :uuid, on_delete: :delete_all), null: false)
      add(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    # Create index for vendor_contacts vendor_id for performance
    create(index(:vendor_contacts, [:vendor_id]))
  end

  def down do
    # Drop the vendor_contacts table and its index
    drop(index(:vendor_contacts, [:vendor_id]))
    drop(table(:vendor_contacts))

    # Drop the unique index
    drop(unique_index(:vendors, [:organisation_id, :name]))

    # Rename the table back from vendors to vendor
    rename(table(:vendors), to: table(:vendor))

    # Drop the added columns
    alter table(:vendor) do
      remove(:city)
      remove(:country)
      remove(:website)
      add(:gstin, :string)
    end
  end
end
