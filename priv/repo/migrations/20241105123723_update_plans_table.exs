defmodule WraftDoc.Repo.Migrations.UpdatePlansTable do
  use Ecto.Migration

  alias WraftDoc.Enterprise

  unless Enterprise.self_hosted?() do
    def change do
      alter table(:plan) do
        remove(:yearly_amount, :string)
        remove(:monthly_amount, :string)

        add(:product_id, :string)
        add(:plan_id, :string)
        add(:plan_amount, :string)
        add(:billing_interval, :string)
        add(:currency, :string)
        add(:features, {:array, :string})
        add(:is_active?, :boolean, default: true)
        add(:type, :string)
        add(:pay_link, :string)
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:limits, :map)
        add(:custom, :map)
        add(:trial_period, :map)
      end

      create(
        unique_index(:plan, [:name, :billing_interval, :is_active?],
          name: :plans_name_billing_interval_active_unique_index
        )
      )

      execute("""
        UPDATE plan
        SET
          name = 'Free trial',
          description = 'Free trial Description',
          features = ARRAY['Feature1', 'Feature2'],
          plan_amount = '0',
          "is_active?" = true,
          limits = '{"instance_create":"20", "content_type_create": 10, "organisation_create": 5, "organisation_invite": 15}',
          type = 'free',
          updated_at = NOW()
        WHERE name = 'Free Trial';
      """)
    end
  end
end
