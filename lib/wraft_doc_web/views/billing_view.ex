defmodule WraftDocWeb.Api.V1.BillingView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.OrganisationView
  alias WraftDocWeb.Api.V1.PlanView
  alias WraftDocWeb.Api.V1.UserView

  def render("subscription.json", %{subscription: subscription}) do
    %{
      id: subscription.id,
      provider_subscription_id: subscription.provider_subscription_id,
      provider_plan_id: subscription.provider_plan_id,
      transaction_id: subscription.transaction_id,
      status: subscription.status,
      start_date: subscription.start_date,
      end_date: subscription.end_date,
      next_bill_date: subscription.next_bill_date,
      next_bill_amount: subscription.next_bill_amount,
      coupon_id: subscription.coupon_id,
      coupon: render_one(subscription.coupon, PlanView, "coupon.json", as: :coupon),
      coupon_start_date: subscription.coupon_start_date,
      coupon_end_date: subscription.coupon_end_date,
      currency: subscription.currency,
      subscriber_id: subscription.subscriber_id,
      subscriber: render_one(subscription.subscriber, UserView, "user.json", as: :user),
      organisation_id: subscription.organisation_id,
      organisation:
        render_one(subscription.organisation, OrganisationView, "organisation.json",
          as: :organisation
        ),
      plan_id: subscription.plan_id,
      plan: render_one(subscription.plan, PlanView, "plan.json", as: :plan)
    }
  end

  def render("change_plan_preview.json", %{
        preview_info: %{
          "status" => status,
          "currency_code" => currency_code,
          "billing_cycle" => %{"frequency" => frequency, "interval" => interval},
          "current_billing_period" => %{"starts_at" => starts_at, "ends_at" => ends_at},
          "immediate_transaction" => %{
            "details" => %{
              "totals" => %{
                "subtotal" => subtotal,
                "tax" => tax,
                "total" => total,
                "discount" => discount
              },
              "line_items" => line_items
            }
          },
          "next_billed_at" => next_billed_at
        }
      }) do
    %{
      status: status,
      currency_code: currency_code,
      billing_cycle: %{
        frequency: frequency,
        interval: interval
      },
      current_billing_period: %{
        starts_at: starts_at,
        ends_at: ends_at
      },
      recurring_transaction_totals: %{
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total
      },
      next_billed_at: next_billed_at,
      plan_pricing: product_details(line_items)
    }
  end

  def render("change_plan.json", %{subscription: subscription}) do
    %{
      message: "Plan changed successfully",
      subscription: render_one(subscription, __MODULE__, "subscription.json", as: :subscription)
    }
  end

  def render("cancel_subscription.json", %{subscription: subscription}) do
    %{
      message: "Subscription canceled successfully",
      subscription: render_one(subscription, __MODULE__, "subscription.json", as: :subscription)
    }
  end

  def render("activate_trial_subscription.json", %{subscription: subscription}) do
    %{
      message: "Trial subscription activated successfully",
      subscription: render_one(subscription, __MODULE__, "subscription.json", as: :subscription)
    }
  end

  def render("invoice.json", %{invoice_url: invoice_url}) do
    %{
      invoice_url: invoice_url
    }
  end

  def render("subscription_history.json", %{subscription_history: subscription_history}) do
    %{
      id: subscription_history.id,
      provider_subscription_id: subscription_history.provider_subscription_id,
      current_subscription_start: subscription_history.current_subscription_start,
      current_subscription_end: subscription_history.current_subscription_end,
      amount: subscription_history.amount,
      event_type: subscription_history.event_type,
      transaction_id: subscription_history.transaction_id,
      subscriber_id: subscription_history.subscriber_id,
      subscriber: render_one(subscription_history.subscriber, UserView, "user.json", as: :user),
      organisation_id: subscription_history.organisation_id,
      organisation:
        render_one(subscription_history.organisation, OrganisationView, "organisation.json",
          as: :organisation
        ),
      plan_id: subscription_history.plan_id,
      plan: render_one(subscription_history.plan, PlanView, "plan.json", as: :plan)
    }
  end

  def render("subscription_history_index.json", %{
        subscription_histories: subscription_histories,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      subscription_histories:
        render_many(subscription_histories, __MODULE__, "subscription_history.json",
          as: :subscription_history
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("transaction.json", %{transaction: transaction}) do
    %{
      id: transaction.id,
      transaction_id: transaction.transaction_id,
      invoice_number: transaction.invoice_number,
      invoice_id: transaction.invoice_id,
      date: transaction.date,
      provider_subscription_id: transaction.provider_subscription_id,
      provider_plan_id: transaction.provider_plan_id,
      billing_period_start: transaction.billing_period_start,
      billing_period_end: transaction.billing_period_end,
      subtotal_amount: transaction.subtotal_amount,
      discount_amount: transaction.discount_amount,
      tax: transaction.tax,
      total_amount: transaction.total_amount,
      currency: transaction.currency,
      payment_method: transaction.payment_method,
      payment_method_details: transaction.payment_method_details,
      coupon_id: transaction.coupon_id,
      coupon: render_one(transaction.coupon, PlanView, "coupon.json", as: :coupon),
      subscriber_id: transaction.subscriber_id,
      subscriber: render_one(transaction.subscriber, UserView, "user.json", as: :user),
      organisation_id: transaction.organisation_id,
      organisation:
        render_one(transaction.organisation, OrganisationView, "organisation.json",
          as: :organisation
        ),
      plan_id: transaction.plan_id,
      plan: render_one(transaction.plan, PlanView, "plan.json", as: :plan)
    }
  end

  def render("transactions_index.json", %{
        transactions: transactions,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      transactions: render_many(transactions, __MODULE__, "transaction.json", as: :transaction),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  defp product_details(items) do
    Enum.map(items, fn %{
                         "product" => %{"name" => name, "description" => description},
                         "totals" => %{
                           "subtotal" => subtotal,
                           "tax" => tax,
                           "total" => total,
                           "discount" => discount
                         }
                       } ->
      %{
        product_name: name,
        description: description,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total
      }
    end)
  end
end
