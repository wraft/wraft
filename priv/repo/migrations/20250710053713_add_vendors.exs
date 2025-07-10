defmodule WraftDoc.Repo.Migrations.MigrateVendorAndAddVendorContacts do
  use Ecto.Migration

  def up do
    # First, add new columns to the existing vendor table
    alter table(:vendor) do
      add(:city, :string)
      add(:country, :string)
      add(:website, :string)
    end

    # Rename the table from vendor to vendors
    rename(table(:vendor), to: table(:vendors))

    # Update foreign key references to use the new table name
    # Note: The original vendor table uses UUID references to :organisation and :user tables
    drop_if_exists(constraint(:vendors, :vendor_organisation_id_fkey))
    drop_if_exists(constraint(:vendors, :vendor_creator_id_fkey))

    create(
      constraint(:vendors, :vendors_organisation_id_fkey,
        foreign_key: [:organisation_id],
        references: :organisations,
        on_delete: :delete_all
      )
    )

    create(
      constraint(:vendors, :vendors_creator_id_fkey,
        foreign_key: [:creator_id],
        references: :users,
        on_delete: :delete_all
      )
    )

    # Create indexes that may be missing
    create_if_not_exists(
      unique_index(:vendors, [:gstin], where: "gstin IS NOT NULL", name: :vendors_gstin_unique)
    )

    create_if_not_exists(
      unique_index(:vendors, [:organisation_id, :name],
        name: :vendors_organisation_id_name_unique
      )
    )

    # Vendor contacts are the people associated with vendors (UUID primary key)
    create table(:vendor_contacts, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:email, :string)
      add(:phone, :string)
      add(:job_title, :string)
      add(:vendor_id, references(:vendors, type: :uuid, on_delete: :delete_all), null: false)
      add(:creator_id, references(:users, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    # Create index for vendor_contacts vendor_id for performance
    create(index(:vendor_contacts, [:vendor_id]))
  end

  def down do
    # Drop vendor_contacts table and its index
    drop(index(:vendor_contacts, [:vendor_id]))
    drop(table(:vendor_contacts))

    # Drop the new indexes
    drop_if_exists(unique_index(:vendors, [:gstin], name: :vendors_gstin_unique))

    drop_if_exists(
      unique_index(:vendors, [:organisation_id, :name],
        name: :vendors_organisation_id_name_unique
      )
    )

    # Remove the new columns
    alter table(:vendors) do
      remove(:city)
      remove(:country)
      remove(:website)
    end

    # Restore original foreign key constraints before renaming
    drop_if_exists(constraint(:vendors, :vendors_organisation_id_fkey))
    drop_if_exists(constraint(:vendors, :vendors_creator_id_fkey))

    # Rename back to vendor
    rename(table(:vendors), to: table(:vendor))

    # Restore original foreign key constraints with original names
    create(
      constraint(:vendor, :vendor_organisation_id_fkey,
        foreign_key: [:organisation_id],
        references: :organisation,
        on_delete: :nilify_all
      )
    )

    create(
      constraint(:vendor, :vendor_creator_id_fkey,
        foreign_key: [:creator_id],
        references: :user,
        on_delete: :nilify_all
      )
    )
  end
end
