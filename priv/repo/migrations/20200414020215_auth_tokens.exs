defmodule WraftDoc.Repo.Migrations.AuthTokens do
  use Ecto.Migration

  def change do
    create table(:auth_token, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:value, :string, null: false)
      add(:token_type, :string)
      add(:expiry_datetime, :naive_datetime)
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
