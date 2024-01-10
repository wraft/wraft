defmodule WraftDoc.Repo.Migrations.ChangeAuthTokenValueToText do
  use Ecto.Migration

  def up do
    alter table(:auth_token) do
      modify(:value, :text)
    end
  end

  def down do
    alter table(:auth_token) do
      modify(:value, :string)
    end
  end
end
