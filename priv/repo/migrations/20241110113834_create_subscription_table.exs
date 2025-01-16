defmodule WraftDoc.Repo.Migrations.CreateSubscriptionTable do
  use Ecto.Migration

  alias WraftDoc.DeploymentMode

  if DeploymentMode.saas?() do
    def change do
      create table(:subscriptions, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add(:provider_subscription_id, :string)
        add(:provider_plan_id, :string)
        add(:provider, :string)
        add(:status, :string)
        add(:type, :string)
        add(:transaction_id, :string)
        add(:current_period_start, :utc_datetime)
        add(:current_period_end, :utc_datetime)
        add(:canceled_at, :utc_datetime)
        add(:next_payment_date, :date)
        add(:next_bill_amount, :string)
        add(:currency, :string)
        add(:update_url, :string)
        add(:cancel_url, :string)
        add(:metadata, :map)

        add(:user_id, references(:user, on_delete: :nothing, type: :uuid))
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:plan_id, references(:plan, on_delete: :nothing, type: :uuid))

        timestamps()
      end

      create(index(:subscriptions, [:user_id]))
      create(index(:subscriptions, [:organisation_id]))
      create(index(:subscriptions, [:plan_id]))
      create(index(:subscriptions, [:provider_subscription_id]))
      create(index(:subscriptions, [:status]))
    end
  end
end
