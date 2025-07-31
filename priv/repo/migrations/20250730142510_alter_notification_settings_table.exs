defmodule WraftDoc.Repo.Migrations.AlterNotificationSettingsTable do
  use Ecto.Migration

  def up do
    drop(constraint(:notification_settings, "notification_settings_organisation_id_fkey"))

    alter table(:notification_settings) do
      modify(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all),
        null: false
      )
    end
  end

  def down do
    drop(constraint(:notification_settings, "notification_settings_organisation_id_fkey"))

    alter table(:notification_settings) do
      modify(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all),
        null: false
      )
    end
  end
end
