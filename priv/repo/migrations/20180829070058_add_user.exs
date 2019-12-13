defmodule ExStarter.Repo.Migrations.AddUser do
  use Ecto.Migration

  def change do
    create table(:user) do
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
