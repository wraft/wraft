defmodule WraftDocWeb.Schemas.Coupon do
  @moduledoc """
  Schema for Coupon request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Coupon do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Coupon",
      description: "A coupon",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Coupon id"},
        name: %Schema{type: :string, description: "Coupon name"},
        description: %Schema{type: :string, description: "Coupon description"},
        coupon_id: %Schema{type: :string, description: "Paddle coupon ID"},
        coupon_code: %Schema{type: :string, description: "Coupon code"},
        amount: %Schema{type: :number, description: "Discount amount"},
        currency: %Schema{type: :string, description: "Currency"},
        type: %Schema{type: :string, description: "Coupon type (flat/percentage)"},
        status: %Schema{type: :string, description: "Coupon status"},
        recurring: %Schema{type: :boolean, description: "Is recurring"},
        maximum_recurring_intervals: %Schema{
          type: :integer,
          description: "Max recurring intervals"
        },
        expiry_date: %Schema{type: :string, description: "Expiry date"},
        usage_limit: %Schema{type: :integer, description: "Usage limit"},
        times_used: %Schema{type: :integer, description: "Times used"}
      },
      example: %{
        id: "coupon_123",
        name: "Welcome Offer",
        description: "20% off",
        coupon_id: "cpn_123",
        coupon_code: "WELCOME20",
        amount: 20,
        currency: "USD",
        type: "percentage",
        status: "active",
        recurring: true,
        maximum_recurring_intervals: 12,
        expiry_date: "2025-12-31",
        usage_limit: 1000,
        times_used: 50
      }
    })
  end
end
