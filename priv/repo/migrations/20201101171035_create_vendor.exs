defmodule WraftDoc.Repo.Migrations.CreateVendor do
  use Ecto.Migration

  def change do
    create table(:vendor, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:email, :string)
      add(:phone, :string)
      add(:address, :string)
      add(:gstin, :string)
      add(:reg_no, :string)
      add(:logo, :string)
      add(:contact_person, :string)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
