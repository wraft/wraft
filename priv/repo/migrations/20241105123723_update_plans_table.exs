defmodule WraftDoc.Repo.Migrations.UpdatePlansTable do
  use Ecto.Migration

  def up do
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
      add(:limits, :map)
      add(:custom, :map)
      add(:trial_period, :map)
      add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
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

  def down do
    alter table(:plan) do
      add(:yearly_amount, :string)
      add(:monthly_amount, :string)

      remove(:product_id)
      remove(:plan_id)
      remove(:plan_amount)
      remove(:billing_interval)
      remove(:currency)
      remove(:features)
      remove(:is_active?)
      remove(:type)
      remove(:pay_link)
      remove(:limits)
      remove(:custom)
      remove(:trial_period)
      remove(:organisation_id)
    end

    drop_if_exists(
      unique_index(:plan, [:name, :billing_interval, :is_active?],
        name: :plans_name_billing_interval_active_unique_index
      )
    )
  end
end
