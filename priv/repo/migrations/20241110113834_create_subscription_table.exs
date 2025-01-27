defmodule WraftDoc.Repo.Migrations.CreateSubscriptionTable do
  use Ecto.Migration

  alias WraftDoc.Enterprise

  if Enterprise.saas?() do
    def change do
      create table(:subscriptions, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add(:provider_subscription_id, :string)
        add(:provider_plan_id, :string)
        add(:status, :string)
        add(:type, :string)
        add(:transaction_id, :string)
        add(:start_date, :utc_datetime)
        add(:end_date, :utc_datetime)
        add(:next_bill_date, :date)
        add(:next_bill_amount, :string)
        add(:currency, :string)
        add(:metadata, :map)

        add(:subscriber_id, references(:user, on_delete: :nothing, type: :uuid))
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:plan_id, references(:plan, on_delete: :nothing, type: :uuid))

        timestamps()
      end

      create(index(:subscriptions, [:organisation_id]))
      create(index(:subscriptions, [:plan_id]))
      create(index(:subscriptions, [:provider_subscription_id]))

      create table(:subscription_history, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add(:provider_subscription_id, :string)
        add(:current_subscription_start, :utc_datetime)
        add(:current_subscription_end, :utc_datetime)
        add(:amount, :string)
        add(:event_type, :string)
        add(:transaction_id, :string)
        add(:metadata, :map)

        add(:subscriber_id, references(:user, on_delete: :nothing, type: :uuid))
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:plan_id, references(:plan, on_delete: :nothing, type: :uuid))

        timestamps()
      end

      create table(:transaction, primary_key: false) do
        add(:id, :uuid, primary_key: true)
        add(:transaction_id, :string)
        add(:invoice_number, :string)
        add(:invoice_id, :string)
        add(:date, :utc_datetime)
        add(:provider_subscription_id, :string)
        add(:provider_plan_id, :string)
        add(:billing_period_start, :utc_datetime)
        add(:billing_period_end, :utc_datetime)
        add(:subtotal_amount, :string)
        add(:tax, :string)
        add(:total_amount, :string)
        add(:currency, :string)

        add(:payment_method, :string)
        add(:payment_method_details, :map)

        add(:subscriber_id, references(:user, on_delete: :nothing, type: :uuid))
        add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
        add(:plan_id, references(:plan, on_delete: :nothing, type: :uuid))

        timestamps()
      end

      create(index(:transaction, [:organisation_id]))
      create(index(:transaction, [:provider_subscription_id]))
    end
  end
end
