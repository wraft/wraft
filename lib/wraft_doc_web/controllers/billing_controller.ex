defmodule WraftDocWeb.Api.V1.BillingController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Billing
  alias WraftDoc.Billing.Subscription

  # TODO add RBAC.
  # TODO add pause and resume subscription API.
  # TODO check possibility of activate-trialing-subscription API.

  def swagger_definitions do
    %{
      Subscription:
        swagger_schema do
          title("Subscription")
          description("A user's subscription details")

          properties do
            id(:integer, "Subscription ID")
            provider_subscription_id(:string, "Provider's subscription ID")
            provider_plan_id(:string, "Provider's plan ID")
            provider(:string, "Subscription provider name")
            status(:string, "Current subscription status")
            current_period_start(:string, "Format: ISO8601 datetime")
            current_period_end(:string, "Format: ISO8601 datetime")
            canceled_at(:string, "Cancellation date if applicable. Format: ISO8601 datetime")
            next_payment_date(:string, "Next payment date. Format: ISO8601 datetime")
            next_bill_amount(:number, "Amount of next bill")
            currency(:string, "Currency code")
            update_url(:string, "URL to update subscription")
            cancel_url(:string, "URL to cancel subscription")
          end
        end,
      IsSubscribed:
        swagger_schema do
          title("Subscription Status")
          description("Simple boolean indicating if user has an active subscription")

          properties do
            is_subscribed(:boolean, "Whether user has an active subscription")
          end
        end,
      ChangePlanPreview:
        swagger_schema do
          title("Plan Change Preview")
          description("Preview information for a plan change")

          properties do
            status(:string, "Status of the preview")
            currency_code(:string, "Currency code for billing")
            billing_cycle(Schema.ref(:BillingCycle), "Billing cycle information")
            current_billing_period(Schema.ref(:BillingPeriod), "Current billing period")

            recurring_transaction_totals(
              Schema.ref(:TransactionTotals),
              "Recurring transaction amounts"
            )

            next_billed_at(:string, "Next billing date. Format: ISO8601 datetime")
            product_details(:array, "List of product details", items: Schema.ref(:ProductDetail))
            management_urls(Schema.ref(:ManagementUrls), "Management URLs")
          end
        end,
      BillingCycle:
        swagger_schema do
          title("Billing Cycle")
          description("Billing cycle details")

          properties do
            frequency(:integer, "Billing frequency")
            interval(:string, "Billing interval (e.g., month, year)")
          end
        end,
      BillingPeriod:
        swagger_schema do
          title("Billing Period")
          description("Start and end dates for billing period")

          properties do
            starts_at(:string, "Period start date. Format: ISO8601 datetime")
            ends_at(:string, "Period end date. Format: ISO8601 datetime")
          end
        end,
      TransactionTotals:
        swagger_schema do
          title("Transaction Totals")
          description("Breakdown of transaction amounts")

          properties do
            subtotal(:number, "Subtotal amount")
            tax(:number, "Tax amount")
            total(:number, "Total amount")
          end
        end,
      ProductDetail:
        swagger_schema do
          title("Product Detail")
          description("Details about a product in the subscription")

          properties do
            product_name(:string, "Name of the product")
            description(:string, "Product description")
            subtotal(:number, "Product subtotal")
            tax(:number, "Product tax")
            total(:number, "Product total")
          end
        end,
      ManagementUrls:
        swagger_schema do
          title("Management URLs")
          description("URLs for managing the subscription")

          properties do
            update_payment_method(:string, "URL to update payment method")
            cancel(:string, "URL to cancel subscription")
          end
        end
    }
  end

  swagger_path :get_active_subscription do
    get("/api/v1/billing/active_subscription")
    summary("Retrieve active subscription")
    description("Fetches the current active subscription for the logged-in user.")

    response(200, "Active subscription retrieved successfully", Schema.ref(:Subscription))
    response(404, "Active subscription not found")
  end

  @spec get_active_subscription(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_active_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <- Billing.active_subscription_for(current_user.id) do
      render(conn, "subscription.json", subscription: subscription)
    end
  end

  swagger_path :ping_subscription do
    get("/api/v1/billing/ping_subscription")
    summary("Check active subscription status")
    description("Returns a boolean indicating if the user has an active subscription.")

    response(200, "Subscription status", Schema.ref(:IsSubscribed))
  end

  @spec ping_subscription(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def ping_subscription(%Plug.Conn{} = conn, _params) do
    current_user = conn.assigns.current_user

    subscribed? = Billing.has_active_subscription?(current_user.id)
    render(conn, "is_subscribed.json", is_subscribed: subscribed?)
  end

  swagger_path :change_plan_preview do
    post("/api/v1/billing/change_plan_preview")
    summary("Preview a plan change")
    description("Provides a preview of subscription changes when switching to a new plan.")

    parameters do
      plan_id(:body, :integer, "New plan ID", required: true)
    end

    response(200, "Change plan preview retrieved successfully", Schema.ref(:ChangePlanPreview))
    response(404, "Active subscription not found")
  end

  @spec change_plan_preview(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def change_plan_preview(conn, %{"plan_id" => plan_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.id),
         {:ok, preview_info} <- Billing.change_plan_preview(subscription, plan_id) do
      render(conn, "change_plan_preview.json", preview_info: preview_info)
    end
  end

  swagger_path :change_plan do
    post("/api/v1/billing/change_plan")
    summary("Change subscription plan")
    description("Applies a new plan to the user's current subscription.")

    parameters do
      new_plan_id(:body, :integer, "New plan ID", required: true)
    end

    response(200, "Plan changed successfully")
    response(404, "Active subscription not found")
  end

  # @spec change_plan(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def change_plan(conn, %{"plan_id" => plan_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.id),
         {:ok, _subscription} <- Billing.change_plan(subscription, plan_id) do
      render(conn, "change_plan_success.json")
    end
  end

  swagger_path :cancel_subscription do
    delete("/api/v1/billing/cancel_subscription")
    summary("Cancel subscription")
    description("Cancels the user's active subscription.")
    response(200, "Subscription cancelled successfully")
    response(404, "Active subscription not found")
  end

  @spec cancel_subscription(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def cancel_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.id),
         {:ok, _subscription} <- Billing.cancel_subscription(subscription) do
      render(conn, "cancel_subscription.json")
    end
  end
end
