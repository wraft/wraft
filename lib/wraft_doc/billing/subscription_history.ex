defmodule WraftDoc.Billing.SubscriptionHistory do
  @moduledoc """
  The subscription history model.
  """
  use WraftDoc.Schema

  schema "subscription_history" do
    field(:provider_subscription_id, :string)
    field(:current_subscription_start, :utc_datetime)
    field(:current_subscription_end, :utc_datetime)
    field(:amount, :string)
    field(:event_type, :string)
    field(:transaction_id, :string)
    field(:metadata, :map)

    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:plan, WraftDoc.Enterprise.Plan)

    timestamps()
  end

  def changeset(subscription_history, attrs) do
    subscription_history
    |> cast(attrs, [
      :provider_subscription_id,
      :current_subscription_start,
      :current_subscription_end,
      :event_type,
      :transaction_id,
      :metadata,
      :user_id,
      :organisation_id,
      :plan_id
    ])
    |> validate_required([
      :provider_subscription_id,
      :current_subscription_start,
      :current_subscription_end,
      :event_type,
      :organisation_id,
      :plan_id
    ])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organisation_id)
    |> foreign_key_constraint(:plan_id)
  end
end
