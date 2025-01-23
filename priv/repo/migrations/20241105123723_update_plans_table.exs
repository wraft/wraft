defmodule WraftDoc.Repo.Migrations.UpdatePlansTable do
  use Ecto.Migration

  alias WraftDoc.DeploymentMode

  if DeploymentMode.saas?() do
    def change do
      alter table(:plan) do
        modify(:yearly_amount, :string)
        modify(:monthly_amount, :string)

        add(:product_id, :string)
        add(:monthly_product_id, :string)
        add(:yearly_product_id, :string)
        add(:custom_price_id, :string)
        add(:features, {:array, :string})
        add(:is_active?, :boolean, default: true)
        add(:type, :string)
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:limits, :map)
        add(:custom, :map)
      end

      execute("""
        UPDATE plan
        SET
          name = 'Free trial',
          description = 'Free trial Description',
          features = ARRAY['Feature1', 'Feature2'],
          monthly_amount = '0',
          yearly_amount = '0',
          "is_active?" = true,
          limits = '{"instance_create":"20", "content_type_create": 10, "organisation_create": 5, "organisation_invite": 15}',
          type = 'free',
          updated_at = NOW()
        WHERE name = 'Free Trial';
      """)
    end
  end
end
