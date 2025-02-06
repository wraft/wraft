defmodule WraftDoc.Repo.Migrations.SeedFreeTrialPlan do
  use Ecto.Migration

  alias WraftDoc.Enterprise

  def up do
    unless Enterprise.self_hosted?() do
      execute("""
        INSERT INTO plan (id, name, description, yearly_amount, monthly_amount, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'Free Trial', 'Free trial where users can try out all the features', 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT DO NOTHING
      """)
    end
  end

  def down do
    unless Enterprise.self_hosted?() do
      execute("DELETE FROM plan WHERE name = 'Free Trial'")
    end
  end
end
