defmodule WraftDoc.Repo.Migrations.CreateOrgansation do
  use Ecto.Migration

  def change do
    alter table(:organisation) do
      add(:legal_name, :string)
      add(:address, :string)
      add(:name_of_ceo, :string)
      add(:name_of_cto, :string)
      add(:gstin, :string)
      add(:corporate_id, :string)
      add(:phone, :string)
      add(:email, :string)
      add(:logo, :string)
    end
  end
end
