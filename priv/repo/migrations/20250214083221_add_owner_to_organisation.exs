defmodule WraftDoc.Repo.Migrations.AddOwnerToOrganisation do
  use Ecto.Migration

  def change do
    alter table(:organisation) do
      add(:owner_id, references(:user, type: :uuid))
    end

    execute("""
    UPDATE organisation o
    SET owner_id = (
    SELECT COALESCE(
        (SELECT uo.user_id
         FROM users_organisations uo
         WHERE uo.organisation_id = o.id
         AND uo.user_id = o.creator_id
         LIMIT 1),
        (SELECT uo.user_id
         FROM users_organisations uo
         WHERE uo.organisation_id = o.id
         ORDER BY uo.inserted_at ASC
         LIMIT 1)
    )
    );

    """)
  end

  def down do
    alter table(:organisation) do
      remove(:owner_id)
    end
  end
end
