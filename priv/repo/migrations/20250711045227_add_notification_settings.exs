defmodule WraftDoc.Repo.Migrations.AddNotificationSettings do
  use Ecto.Migration

  def up do
    create table(:notification_settings, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:events, {:array, :string})

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all),
        null: false
      )

      timestamps()
    end

    create(index(:notification_settings, [:organisation_id]))
  end

  def down do
    drop(table(:notification_settings))
  end
end
