defmodule WraftDoc.Repo.Migrations.RemoveNotContraintBetweenOrganisationAndFlow do
  use Ecto.Migration

  def change do
    alter table(:flow) do
      modify(:organisation_id, :uuid, null: true, from: {:uuid, null: false})
    end
  end
end
