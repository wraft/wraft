defmodule WraftDoc.Repo.Migrations.AddNotificationPreferences do
  use Ecto.Migration

  def up do
    create table(:notification_preferences, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:preference, :map)

      add(:event_id, references(:events, type: :uuid, on_delete: :nilify_all), null: false)

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all),
        null: true
      )

      timestamps()
    end

    create(index(:notification_preferences, [:organisation_id]))
  end

  def down do
    drop(table(:notification_preferences))
  end
end
