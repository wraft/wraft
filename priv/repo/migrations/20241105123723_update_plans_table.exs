defmodule WraftDoc.Repo.Migrations.UpdatePlansTable do
  use Ecto.Migration

  def change do
    alter table(:plan) do
      # remove(:yearly_amount)
      # remove(:monthly_amount)
      modify(:yearly_amount, :string, null: false)
      modify(:monthly_amount, :string, null: false)

      add(:paddle_product_id, :string)
      add(:monthly_price_id, :string)
      # add(:monthly_amount, :string, null: false)
      add(:yearly_price_id, :string)
      # add(:yearly_amount, :string, null: false)
      add(:limits, :map)
    end
  end
end
