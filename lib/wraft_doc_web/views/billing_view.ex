defmodule WraftDocWeb.Api.V1.BillingView do
  use WraftDocWeb, :view

  def render("subscription.json", %{subscription: subscription}) do
    %{
      id: subscription.id,
      provider_subscription_id: subscription.provider_subscription_id,
      provider_plan_id: subscription.provider_plan_id,
      provider: subscription.provider,
      status: subscription.status,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      canceled_at: subscription.canceled_at,
      next_payment_date: subscription.next_payment_date,
      next_bill_amount: subscription.next_bill_amount,
      currency: subscription.currency,
      update_url: subscription.update_url,
      cancel_url: subscription.cancel_url
    }
  end

  def render("is_subscribed.json", %{is_subscribed: is_subscribed}) do
    %{
      is_subscribed: is_subscribed
    }
  end

  def render("change_plan_preview.json", %{preview_info: preview_info}) do
    %{
      status: preview_info["data"]["status"],
      currency_code: preview_info["data"]["currency_code"],
      billing_cycle: %{
        frequency: preview_info["data"]["billing_cycle"]["frequency"],
        interval: preview_info["data"]["billing_cycle"]["interval"]
      },
      current_billing_period: %{
        starts_at: preview_info["data"]["current_billing_period"]["starts_at"],
        ends_at: preview_info["data"]["current_billing_period"]["ends_at"]
      },
      recurring_transaction_totals: %{
        subtotal: preview_info["data"]["recurring_transaction_details"]["totals"]["subtotal"],
        tax: preview_info["data"]["recurring_transaction_details"]["totals"]["tax"],
        total: preview_info["data"]["recurring_transaction_details"]["totals"]["total"]
      },
      next_billed_at: preview_info["data"]["next_billed_at"],
      product_details:
        product_details(preview_info["data"]["recurring_transaction_details"]["line_items"]),
      management_urls: %{
        update_payment_method: preview_info["data"]["management_urls"]["update_payment_method"],
        cancel: preview_info["data"]["management_urls"]["cancel"]
      }
    }
  end

  def render("change_plan_success.json", _) do
    %{
      message: "Plan changed successfully"
    }
  end

  def render("cancel_subscription.json", _) do
    %{
      message: "Subscription canceled successfully"
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
