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
      provider: subscription.provider,
      status: subscription.status,
      type: subscription.type,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      canceled_at: subscription.canceled_at,
      next_payment_date: subscription.next_payment_date,
      next_bill_amount: subscription.next_bill_amount,
      currency: subscription.currency,
      update_url: subscription.update_url,
      cancel_url: subscription.cancel_url,
      user_id: subscription.user_id,
      user: render_one(subscription.user, UserView, "user.json", as: :user),
      organisation_id: subscription.organisation_id,
      organisation:
        render_one(subscription.organisation, OrganisationView, "organisation.json",
          as: :organisation
        ),
      plan_id: subscription.plan_id,
      plan: render_one(subscription.plan, PlanView, "plan.json", as: :plan)
    }
  end

  def render("change_plan_preview.json", %{preview_info: preview_info}) do
    %{
      status: preview_info["status"],
      currency_code: preview_info["currency_code"],
      billing_cycle: %{
        frequency: preview_info["billing_cycle"]["frequency"],
        interval: preview_info["billing_cycle"]["interval"]
      },
      current_billing_period: %{
        starts_at: preview_info["current_billing_period"]["starts_at"],
        ends_at: preview_info["current_billing_period"]["ends_at"]
      },
      recurring_transaction_totals: %{
        subtotal: preview_info["recurring_transaction_details"]["totals"]["subtotal"],
        tax: preview_info["recurring_transaction_details"]["totals"]["tax"],
        total: preview_info["recurring_transaction_details"]["totals"]["total"]
      },
      next_billed_at: preview_info["next_billed_at"],
      product_details:
        product_details(preview_info["recurring_transaction_details"]["line_items"])
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
      plan_name: subscription_history.plan_name,
      event_type: subscription_history.event_type,
      transaction_id: subscription_history.transaction_id,
      user_id: subscription_history.user_id,
      user: render_one(subscription_history.user, UserView, "user.json", as: :user),
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
      tax: transaction.tax,
      total_amount: transaction.total_amount,
      currency: transaction.currency,
      payment_method: transaction.payment_method,
      payment_method_details: transaction.payment_method_details,
      user_id: transaction.user_id,
      user: render_one(transaction.user, UserView, "user.json", as: :user),
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
    Enum.map(items, fn item ->
      %{
        product_name: item["product"]["name"],
        description: item["product"]["description"],
        subtotal: item["totals"]["subtotal"],
        tax: item["totals"]["tax"],
        total: item["totals"]["total"]
      }
    end)
  end
end
