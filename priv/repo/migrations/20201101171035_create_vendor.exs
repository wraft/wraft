defmodule WraftDoc.Repo.Migrations.CreateVendor do
  use Ecto.Migration

  def change do
    create table(:vendor)do
      add :uuid, :uuid, null: false
      add :name, :string
      add :email, :string
      add :phone, :string
      add :address, :string
      add :gstin, :string
      add :reg_no, :string
      add :logo, :string
      add :contact_person, :string
      add :organisation_id, references(:organisation, on_delete: :nilify_all)
      add :creator_id, references(:user, on_delete: :nilify_all)
      timestamps()
     end
  end
end
