defmodule WraftDoc.Repo.Migrations.UpdateNotificationTableAddScopeAndType do
  use Ecto.Migration

  def up do
    rename(table("notification"), to: table("notifications"))

    alter table(:notifications) do
      add(:event_type, :string)
      add(:channel, :string)
      add(:channel_id, :string)
      add(:metadata, :map, default: %{})

      remove(:actor_id)

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:notifications) do
      remove(:event_type)
      remove(:channel_id)
      remove(:channel)
      remove(:organisation_id)
      remove(:metadata)

      add(:actor_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    rename(table("notifications"), to: table("notification"))
  end
end
