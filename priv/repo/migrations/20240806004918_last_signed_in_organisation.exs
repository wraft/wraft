defmodule WraftDoc.Repo.Migrations.LastSignedInOrganisation do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add(:last_signed_in_org, :uuid)
    end
  end
end
