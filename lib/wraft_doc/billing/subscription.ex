defmodule WraftDoc.Billing.Subscription do
  @moduledoc """
  The subscription model.
  """
  use WraftDoc.Schema

  @type t :: %__MODULE__{}

  @changeset_fields [
    :provider_subscription_id,
    :provider_plan_id,
    :status,
    :start_date,
    :end_date,
    :next_bill_date,
    :next_bill_amount,
    :currency,
    :metadata,
    :subscriber_id,
    :organisation_id,
    :plan_id,
    :transaction_id
  ]

  schema "subscriptions" do
    field(:provider_subscription_id, :string)
    field(:provider_plan_id, :string)
    field(:status, :string)
    field(:start_date, :utc_datetime)
    field(:end_date, :utc_datetime)
    field(:next_bill_date, :date)
    field(:next_bill_amount, :string)
    field(:currency, :string)
    field(:metadata, :map)
    field(:transaction_id, :string)

    belongs_to(:subscriber, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:plan, WraftDoc.Enterprise.Plan)

    timestamps()
  end

  def changeset(subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, @changeset_fields)
    |> validate_required([
      :provider_subscription_id,
      :provider_plan_id,
      :status,
      :start_date,
      :end_date,
      :next_bill_amount,
      :currency,
      :transaction_id,
      :organisation_id,
      :plan_id,
      :subscriber_id
    ])
    |> unique_constraint(:provider_subscription_id)
    |> foreign_key_constraint(:plan_id,
      name: :subscriptions_plan_id_fkey,
      message: "Cannot delete plan due to associated subscriptions."
    )
  end

  def update_changeset(subscription, attrs \\ %{}) do
    subscription
    |> cast(attrs, @changeset_fields)
    |> validate_required([
      :provider_subscription_id,
      :provider_plan_id,
      :status,
      :start_date,
      :end_date,
      :next_bill_amount,
      :currency,
      :subscriber_id,
      :organisation_id,
      :plan_id
    ])
    |> unique_constraint(:provider_subscription_id)
  end

  def free_subscription_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, @changeset_fields)
    |> validate_required([
      :next_bill_amount,
      :currency,
      :organisation_id,
      :plan_id
    ])
  end
end
