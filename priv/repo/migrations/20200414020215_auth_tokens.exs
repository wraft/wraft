defmodule WraftDoc.Repo.Migrations.AuthTokens do
  use Ecto.Migration

  def change do
    create table(:auth_token) do
      add(:uuid, :uuid, null: false)
      add(:value, :string, null: false)
      add(:token_type, :string)
      add(:expiry_datetime, :naive_datetime)
      add(:user_id, references(:user))
    end
  end
end
