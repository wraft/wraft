defmodule WraftDoc.Repo.Migrations.AddTimestampsToAuthTokens do
  use Ecto.Migration

  def change do
    alter table(:auth_token) do
      timestamps()
    end
  end
end
