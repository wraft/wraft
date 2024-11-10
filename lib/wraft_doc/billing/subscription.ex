defmodule WraftDoc.Billing.Subscription do
  @moduledoc """
  The subscription model.
  """
  use WraftDoc.Schema

  schema "subscriptions" do
    field(:provider_subscription_id, :string)
    field(:provider_plan_id, :string)
    field(:provider, :string)
    field(:status, :string)
    field(:current_period_start, :utc_datetime)
    field(:current_period_end, :utc_datetime)
    field(:canceled_at, :utc_datetime)
    field(:next_payment_date, :date)
    field(:next_bill_amount, :string)
    field(:currency, :string)
    field(:update_url, :string)
    field(:cancel_url, :string)
    field(:metadata, :map)

    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:plan, WraftDoc.Enterprise.Plan)

    timestamps()
  end

  def changeset(subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, [
      :provider_subscription_id,
      :provider_plan_id,
      :provider,
      :status,
      :current_period_start,
      :current_period_end,
      :canceled_at,
      :next_payment_date,
      :next_bill_amount,
      :currency,
      :update_url,
      :cancel_url,
      :metadata,
      :user_id,
      :organisation_id,
      :plan_id
    ])
    |> validate_required([
      :provider_subscription_id,
      :provider_plan_id,
      :provider,
      :status,
      :current_period_start,
      :current_period_end,
      :next_bill_amount,
      :currency,
      :user_id,
      :organisation_id,
      :plan_id
    ])
    |> unique_constraint(:provider_subscription_id)
    |> validate_format(:currency, ~r/^[A-Z]{3}$/)
  end
end
