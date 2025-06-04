defmodule WraftDoc.Repo.Migrations.AlterCouponAddCreator do
  use Ecto.Migration

  def up do
    alter table(:coupon) do
      add(:creator_id, references(:internal_user, type: :uuid, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:coupon) do
      remove(:creator_id)
    end
  end
end
