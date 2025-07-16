defmodule WraftDoc.Repo.Migrations.UpdateNotificationTableAddScopeAndType do
  use Ecto.Migration

  def up do
    rename(table("notification"), to: table("notifications"))

    alter table(:notifications) do
      add(:event_type, :string)
      add(:channel, :string)
      add(:channel_id, :string)
      add(:metadata, :map, default: %{})

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all))

      remove(:type)
    end

    alter table(:user_notifications) do
      remove(:status)
      add(:read, :boolean, default: false, null: false)
    end
  end

  def down do
    alter table(:notifications) do
      remove(:event_type)
      remove(:channel_id)
      remove(:channel)
      remove(:organisation_id)
      remove(:metadata)

      add(:type, :string)
    end

    rename(table("notifications"), to: table("notification"))

    alter table(:user_notifications) do
      remove(:read)
      add(:status, :string)
    end
  end
end
