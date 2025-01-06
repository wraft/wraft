defmodule WraftDoc.Repo.Migrations.UpdatePlansTable do
  use Ecto.Migration

  alias WraftDoc.DeploymentMode

  if DeploymentMode.saas?() do
    def change do
      alter table(:plan) do
        modify(:yearly_amount, :string)
        modify(:monthly_amount, :string)

        add(:paddle_product_id, :string)
        add(:monthly_price_id, :string)
        add(:yearly_price_id, :string)
        add(:custom_price_id, :string)
        add(:limits, :map)
        add(:custom, :map)
      end
    end
  end
end
