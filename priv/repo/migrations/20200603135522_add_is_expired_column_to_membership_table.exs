defmodule WraftDoc.Repo.Migrations.AddIsExpiredColumnToMembershipTable do
  use Ecto.Migration

  alias WraftDoc.Enterprise

  def up do
    unless Enterprise.self_hosted?() do
      alter table(:membership) do
        add(:is_expired, :boolean, default: false)
      end
    end
  end

  def down do
    unless Enterprise.self_hosted?() do
      alter table(:membership) do
        remove(:is_expired)
      end
    end
  end
end
