defmodule WraftDoc.Repo.Migrations.UpdateNotificationTableAddScopeAndType do
  use Ecto.Migration

  def up do
    alter table(:notification) do
      add(:scope, :string)
      add(:scope_id, :string)
      add(:channel, :string)
    end

    rename(table(:notification), :type, to: :event_type)
  end

  def down do
    alter table(:notification) do
      remove(:scope)
      remove(:scope_id)
      remove(:channel)
    end

    rename(table(:notification), :event_type, to: :type)
  end
end
