defmodule WraftDoc.Repo.Migrations.RevampNotificationTablesToBeScalable do
  @moduledoc """
  Migration script for revamping notification tables to be scalable
  """
  use Ecto.Migration

  def up do
    alter table(:notification) do
      add(:message, :text)
      add(:is_global, :boolean, default: false)
      remove(:action)
      remove(:read_at)
      remove(:read)
      remove(:recipient_id)
      remove(:notifiable_id)
    end

    rename(table(:notification), :notifiable_type, to: :type)

    create table(:user_notifications, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:status, :string)
      add(:seen_at, :utc_datetime)
      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all))
      add(:recipient_id, references(:user, type: :uuid, on_delete: :delete_all))
      add(:notification_id, references(:notification, type: :uuid, on_delete: :delete_all))

      timestamps()
    end

    create(
      unique_index(:user_notifications, [:recipient_id, :notification_id],
        name: :unique_user_notification
      )
    )

    alter table(:notification) do
      add(:action, :map)
    end
  end

  def down do
    alter table(:notification) do
      remove(:message)
      remove(:is_global)
      modify(:action, :string, from: :map)
      add(:notifiable_id, :uuid)
      add(:read_at, :naive_datetime)
      add(:read, :boolean, default: false)
      add(:recipient_id, references(:user, type: :uuid, on_delete: :delete_all))
    end

    rename(table(:notification), :type, to: :notifiable_type)

    drop(
      unique_index(:user_notifications, [:recipient_id, :notification_id],
        name: :unique_user_notification
      )
    )

    drop(table(:user_notifications))
  end
end
