defmodule WraftDocWeb.CouponAdmin do
  @moduledoc """
  Admin panel for coupon module
  """
  import Ecto.Query
  use Ecto.Schema

  alias WraftDoc.Billing
  alias WraftDoc.Billing.Coupon

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      description: %{name: "Description", value: fn x -> x.description end},
      status: %{name: "Status", value: fn x -> x.status end},
      type: %{name: "Type", value: fn x -> x.type end},
      coupon_code: %{name: "Coupon code", value: fn x -> x.coupon_code end},
      amount: %{name: "Amount", value: fn x -> x.amount end},
      currency: %{name: "Currency", value: fn x -> x.currency end},
      recurring: %{name: "Recurring", value: fn x -> x.recurring end},
      maximum_recurring_intervals: %{
        name: "Maximum recurring intervals",
        value: fn x ->
          cond do
            x.recurring && is_nil(x.maximum_recurring_intervals) ->
              "Recur forever"

            x.recurring == false ->
              "Not recurring"

            true ->
              x.maximum_recurring_intervals
          end
        end
      },
      start_date: nil,
      expiry_date: %{
        name: "Expiry",
        value: fn x ->
          if x.expiry_date == nil do
            "Valid forever"
          else
            x.expiry_date
          end
        end
      },
      creator: %{
        name: "Creator",
        value: fn x ->
          if x.creator do
            Map.get(x.creator, :email)
          else
            "Nil"
          end
        end
      }
    ]
  end

  # TODO allowed products?
  def form_fields(_) do
    [
      name: %{label: "Name"},
      description: %{label: "Description"},
      status: %{
        label: "Status",
        type: :choices,
        choices: [
          {"active", :active},
          {"archived", :archived}
        ]
      },
      type: %{
        label: "Type",
        type: :choices,
        choices: [
          {"flat", :flat},
          {"percentage", :percentage}
        ],
        help_text: "Flat or percentage"
      },
      amount: %{label: "Amount", help_text: "If flat, enter amount, else percentage"},
      coupon_code: %{label: "Coupon code", help_text: "Add or keep empty for generated codes"},
      currency: %{
        label: "Currency",
        help_text:
          "Specify the currency to be used. Available currency codes include USD, EUR, GBP, CAD, AUD, NZD, and others supported by Paddle."
      },
      recurring: %{
        label: "Recurring",
        type: :boolean,
        help_text: "Applies for multiple subscription billing periods."
      },
      maximum_recurring_intervals: %{
        label: "maximum_recurring_intervals",
        type: :integer,
        help_text: "Keep empty for recur forever"
      },
      expiry_date: %{label: "Expiry", help_text: "Nil, valid forever"},
      times_used: %{label: "Times used", type: :integer, create: :readonly, update: :readonly},
      usage_limit: %{label: "Usage limit", type: :integer}
    ]
  end

  def custom_index_query(_conn, _schema, _query) do
    from(c in Coupon,
      preload: [:creator]
    )
  end

  def insert(
        %{assigns: %{admin_session: %{id: internal_user_id}}, params: %{"coupon" => params}},
        _changeset
      ) do
    changeset = Coupon.changeset(%Coupon{}, Map.put(params, "creator_id", internal_user_id))

    changeset.changes
    |> Billing.create_coupon()
    |> Billing.handle_response(changeset)
  end

  def update(%{params: %{"coupon" => params}}, changeset) do
    formatted_changeset = Coupon.changeset(%Coupon{}, params)

    changeset.data
    |> Billing.update_coupon(Map.merge(formatted_changeset.changes, changeset.changes))
    |> Billing.handle_response(changeset)
  end

  def delete(_conn, changeset) do
    changeset.data
    |> Billing.delete_coupon()
    |> Billing.handle_response(changeset)
  end
end
