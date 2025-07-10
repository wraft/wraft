defmodule WraftDoc.Repo.Migrations.AddVendors do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Vendors represent organizations that provide goods/services
    create table(:vendors) do
      add(:name, :string, null: false, comment: "Official name of the vendor")
      add(:gstin, :string, comment: "Goods and Services Tax Identification Number")
      add(:website, :string)
      add(:address, :string)
      add(:city, :string)
      add(:country, :string)
      add(:creator_id, references(:users, on_delete: :delete_all), null: false)
      add(:organisation_id, references(:organisations, on_delete: :delete_all), null: false)
      add(:content_id, references(:contents, on_delete: :nilify_all))

      timestamps()
    end

    # Vendor contacts are the people associated with vendors
    create table(:vendor_contacts) do
      add(:name, :string, null: false)
      add(:email, :string)
      add(:phone, :string)
      add(:job_title, :string)
      add(:vendor_id, references(:vendors, on_delete: :delete_all), null: false)
      add(:counter_party_id, references(:counter_parties, on_delete: :nilify_all))

      timestamps()
    end

    # Create indexes concurrently to avoid locking the table
    execute(
      "CREATE INDEX CONCURRENTLY IF NOT EXISTS vendor_contacts_vendor_id_index ON vendor_contacts(vendor_id)",
      "DROP INDEX IF EXISTS vendor_contacts_vendor_id_index"
    )

    # Unique indexes with proper naming and conditions
    create(
      unique_index(:vendors, [:gstin], where: "gstin IS NOT NULL", name: :vendors_gstin_unique)
    )

    # Ensure unique vendor names per organization
    create(
      unique_index(:vendors, [:organisation_id, :name],
        name: :vendors_organisation_id_name_unique
      )
    )

    # Ensure a counter party can only be associated with a vendor once
    create(
      unique_index(:vendor_contacts, [:vendor_id, :counter_party_id],
        where: "counter_party_id IS NOT NULL",
        name: :vendor_contacts_vendor_counter_party_unique
      )
    )
  end
end
