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
        add(:features, {:array, :string})
        add(:is_active?, :boolean, default: true)
        add(:type, :string)
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:limits, :map)
        add(:custom, :map)
      end

      # execute("TRUNCATE TABLE plan CASCADE")
      execute("DELETE FROM plan WHERE name = 'Free Trial'")

      execute("""
        INSERT INTO plan (id, name, description, features, monthly_amount, yearly_amount, "is_active?", limits, type, inserted_at, updated_at)
        VALUES
        (
          '#{Ecto.UUID.generate()}',
          'Free trial',
          'Free trial Description',
          ARRAY['Feature1', 'Feature2'],
          '0',
          '0',
          true,
          '{"instance_create":"20", "content_type_create": 10, "organisation_create": 5, "organisation_invite": 15}',
          'free',
          NOW(),
          NOW()
        );
      """)
    end
  end
end
