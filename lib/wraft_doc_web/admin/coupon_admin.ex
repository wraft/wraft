defmodule WraftDocWeb.CouponAdmin do
  @moduledoc """
  Admin panel for coupon module
  """
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
      expiry: %{
        name: "Expiry",
        value: fn x ->
          if x.expiry == nil do
            "Valid forever"
          else
            x.expiry
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
          {"inactive", :inactive}
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
      expiry: %{label: "Expiry", help_text: "Nil, valid forever"},
      times_used: %{label: "Times used", type: :integer},
      usage_limit: %{label: "Usage limit", type: :integer}
    ]
  end

  def insert(conn, _changeset) do
    changeset = Coupon.changeset(%Coupon{}, conn.params["coupon"])

    changeset.changes
    |> Billing.create_coupon()
    |> handle_repsonse(changeset)
  end

  def update(conn, changeset) do
    formatted_changeset = Coupon.changeset(%Coupon{}, conn.params["coupon"])

    changeset.data
    |> Billing.update_coupon(formatted_changeset.changes)
    |> handle_repsonse(changeset)
  end

  # TODO: Delete not ideal, provider keeps the coupon cant be reused.
  def delete(_conn, changeset) do
    changeset.data
    |> Billing.delete_coupon()
    |> handle_repsonse(changeset)
  end

  defp handle_repsonse(response, changeset) do
    case response do
      {:ok, plan} ->
        {:ok, plan}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, error} ->
        {:error, {changeset, error}}
    end
  end
end
