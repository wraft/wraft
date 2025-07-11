defmodule WraftDoc.Repo.Migrations.UpdateNotificationTableAddScopeAndType do
  use Ecto.Migration

  def up do
    alter table(:notification) do
      add(:event_type, :string)
      add(:channel, :string)
      add(:channel_id, :string)

      remove(:actor_id)

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:notification) do
      remove(:event_type)
      remove(:channel_id)
      remove(:channel)
      remove(:organisation_id)

      add(:actor_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end
end
