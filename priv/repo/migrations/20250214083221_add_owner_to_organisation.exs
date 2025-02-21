defmodule WraftDoc.Repo.Migrations.AddOwnerToOrganisation do
  use Ecto.Migration

  def change do
    alter table(:organisation) do
      add(:owner_id, :uuid)
    end
  end
end
