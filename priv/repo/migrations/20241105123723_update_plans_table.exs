defmodule WraftDoc.Repo.Migrations.UpdatePlansTable do
  use Ecto.Migration

  def change do
    alter table(:plan) do
      modify(:yearly_amount, :string, null: false)
      modify(:monthly_amount, :string, null: false)

      add(:yearly_product_id, :string)
      add(:monthly_product_id, :string)

      add(:limits, :map)
    end
  end
end
