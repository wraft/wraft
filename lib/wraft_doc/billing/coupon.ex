defmodule WraftDoc.Billing.Coupon do
  @moduledoc """
  The coupon model.
  """
  use WraftDoc.Schema

  alias WraftDoc.InternalUsers.InternalUser

  @fields [
    :name,
    :description,
    :coupon_id,
    :status,
    :type,
    :coupon_code,
    :amount,
    :currency,
    :recurring,
    :maximum_recurring_intervals,
    :usage_limit,
    :times_used,
    :expiry_date,
    :start_date,
    :creator_id
  ]

  @required_fields [
    :name,
    :description,
    :type,
    :amount,
    :currency
  ]

  schema "coupon" do
    field(:name, :string)
    field(:description, :string)
    field(:coupon_id, :string)
    field(:status, Ecto.Enum, values: [:active, :expired, :archived])
    field(:type, Ecto.Enum, values: [:percentage, :flat])
    field(:coupon_code, :string)
    field(:amount, :string)
    field(:currency, :string, default: "USD")
    field(:recurring, :boolean, default: false)
    field(:maximum_recurring_intervals, :integer, default: nil)
    field(:start_date, :utc_datetime, default: nil)
    field(:expiry_date, :utc_datetime, default: nil)
    field(:usage_limit, :integer, default: nil)
    field(:times_used, :integer, default: 0)

    belongs_to(:creator, InternalUser)

    timestamps()
  end

  def changeset(coupon, attrs) do
    coupon
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name,
      name: :coupon_name_index,
      message: "A coupon with the same name exists!"
    )
    |> unique_constraint(:coupon_code,
      name: :coupon_code_index,
      message: "A coupon with the same coupon code exists!"
    )
  end
end
