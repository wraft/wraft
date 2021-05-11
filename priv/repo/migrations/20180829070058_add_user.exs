defmodule WraftDoc.Repo.Migrations.AddUser do
  use Ecto.Migration

  def change do
    create table(:user, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:email, :string, null: false)
      add(:encrypted_password, :string, null: false)
      add(:mobile, :string, null: false)
      add(:email_verify, :boolean, default: false)
      timestamps()
    end

    create(unique_index(:user, [:email]))
  end
end
