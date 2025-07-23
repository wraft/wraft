defmodule WraftDoc.Repo.Migrations.AddPartyTypeAndSignatureFieldsToCounterParties do
  use Ecto.Migration

  def change do
    # Create party_types table
    create table(:party_types) do
      add(:name, :string, null: false, comment: "Type name: external, vendor, current_org")

      add(:sign_order, :integer,
        null: false,
        comment: "Order in which this party type should sign"
      )

      add(:organisation_id, references(:organisations, on_delete: :delete_all), null: true)

      timestamps()
    end

    create(unique_index(:party_types, [:name, :organisation_id]))
    create(index(:party_types, [:organisation_id]))

    # Add new fields to counter_parties table
    alter table(:counter_parties) do
      add(:party_type, :string, comment: "Type of party: external, vendor, current_org")

      add(:signature_type, :string,
        comment: "Type of signature: electronic, digital, zoho_sign, docusign"
      )

      add(:sign_order, :integer, comment: "Order in which this counterparty should sign")
      add(:party_type_id, references(:party_types, on_delete: :nilify_all), null: true)
    end

    create(index(:counter_parties, [:party_type_id]))
    create(index(:counter_parties, [:party_type]))
    create(index(:counter_parties, [:signature_type]))
    create(index(:counter_parties, [:sign_order]))
  end
end
