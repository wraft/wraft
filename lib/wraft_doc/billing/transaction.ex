defmodule WraftDoc.Billing.Transaction do
  @moduledoc """
  The subscription model.
  """
  use WraftDoc.Schema

  @type t :: %__MODULE__{}

  schema "transaction" do
    field(:transaction_id, :string)
    field(:invoice_number, :string)
    field(:invoice_id, :string)
    field(:date, :utc_datetime)
    field(:provider_subscription_id, :string)
    field(:provider_plan_id, :string)
    field(:billing_period_start, :utc_datetime)
    field(:billing_period_end, :utc_datetime)
    field(:subtotal_amount, :string)
    field(:tax, :string)
    field(:total_amount, :string)
    field(:currency, :string)
    field(:payment_method, :string)
    field(:payment_method_details, :map)
    # TODO add dscount amount

    belongs_to(:subscriber, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:plan, WraftDoc.Enterprise.Plan)

    timestamps()
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :transaction_id,
      :invoice_number,
      :invoice_id,
      :date,
      :provider_subscription_id,
      :provider_plan_id,
      :billing_period_start,
      :billing_period_end,
      :subtotal_amount,
      :tax,
      :total_amount,
      :currency,
      :payment_method,
      :payment_method_details,
      :subscriber_id,
      :organisation_id,
      :plan_id
    ])
    |> validate_required([
      :transaction_id,
      :date,
      :provider_subscription_id,
      :provider_plan_id,
      :billing_period_start,
      :billing_period_end,
      :subtotal_amount,
      :tax,
      :total_amount,
      :currency,
      :organisation_id,
      :plan_id
    ])
  end
end
