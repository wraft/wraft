defmodule WraftDoc.Repo.Migrations.AddIsExpiredColumnToMembershipTable do
  use Ecto.Migration

  def up do
    alter table(:membership) do
      add(:is_expired, :boolean, default: false)
    end
  end

  def down do
    alter table(:membership) do
      remove(:is_expired)
    end
  end
end
