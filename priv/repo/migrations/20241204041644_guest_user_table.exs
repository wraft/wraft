defmodule WraftDoc.Repo.Migrations.GuestUserTable do
  use Ecto.Migration

  def change do
    create table(:guest_user, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:email, :string, null: false)
      timestamps()
    end
  end
end
