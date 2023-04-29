defmodule WraftDoc.Repo.Migrations.CreateInternalUserTable do
  use Ecto.Migration

  def change do
    create table(:internal_user, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:email, :string, null: false)
      add(:encrypted_password, :string, null: false)
      timestamps()
    end

    create(unique_index(:internal_user, [:email]))
  end
end
