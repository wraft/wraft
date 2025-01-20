defmodule WraftDocWeb.Api.V1.BillingController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Billing
  alias WraftDoc.Billing.PaddleApi
  alias WraftDoc.Billing.Subscription

  # TODO add RBAC.
  # TODO add pause and resume subscription API.

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
            organisation_id(:string, "Organization ID")
            user_id(:string, "User ID")
            plan_id(:string, "Plan ID")
            update_url(:string, "URL to update subscription")
            cancel_url(:string, "URL to cancel subscription")
          end
        end,
      InvoiceUrl:
        swagger_schema do
          title("Invoice url")
          description("The url for invoice pdf.")

          properties do
            invoice_url(:string, "Invoice url")
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
        end,
      Transaction:
        swagger_schema do
          title("Transaction")
          description("Transaction details")

          properties do
            id(:string, "Transaction ID")
            user_id(:string, "User ID")
            org_id(:string, "Organization ID")
            amount(:number, "Transaction amount")
            currency(:string, "Transaction currency")
            description(:string, "Transaction description")
            created_at(:string, "Transaction creation date. Format: ISO8601 datetime")
            updated_at(:string, "Transaction update date. Format: ISO8601 datetime")
            status(:string, "Transaction status")
            type(:string, "Transaction type")
            payment_method(:string, "Payment method used for the transaction")
            payment_method_details(:string, "Details about the payment method")
          end
        end,
      Transactions:
        swagger_schema do
          title("Transaction")
          description("Transaction details")

          properties do
            transactions(Schema.ref(:Transaction))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end
        end,
      SubscriptionHistory:
        swagger_schema do
          title("Subscription History")
          description("Subscription history details")

          properties do
            subscription_history(Schema.ref(:SubscriptionHistory))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end
        end
    }
  end

  swagger_path :get_active_subscription do
    get("/billing/subscription/active")
    summary("Retrieve active subscription")
    description("Fetches the current active subscription for the logged-in user.")

    response(200, "Active subscription retrieved successfully", Schema.ref(:Subscription))
    response(404, "Active subscription not found")
  end

  @spec get_active_subscription(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_active_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.current_org_id) do
      render(conn, "subscription.json", subscription: subscription)
    end
  end

  swagger_path :get_subsctiption do
    get("/billing/subscription/get_subsctiption")
    summary("Get subscription")
    description("Gets the current subscription of current organisation")

    response(200, "Subscription status", Schema.ref(:IsSubscribed))
    response(404, "Subscription not found")
  end

  @spec get_subsctiption(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_subsctiption(%Plug.Conn{} = conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user) do
      render(conn, "subscription.json", subscription: subscription)
    end
  end

  swagger_path :change_plan_preview do
    post("/billing/change_plan_preview")
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
           Billing.active_subscription_for(current_user.current_org_id),
         {:ok, preview_info} <- Billing.change_plan_preview(subscription, plan_id) do
      render(conn, "change_plan_preview.json", preview_info: preview_info)
    end
  end

  swagger_path :change_plan do
    post("/billing/change_plan")
    summary("Change subscription plan")
    description("Applies a new plan to the user's current subscription.")

    parameters do
      new_plan_id(:body, :integer, "New plan ID", required: true)
    end

    response(200, "Plan changed successfully")
    response(404, "Active subscription not found")
  end

  @spec change_plan(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def change_plan(conn, %{"plan_id" => plan_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.current_org_id),
         {:ok, _subscription} <- Billing.change_plan(subscription, plan_id) do
      render(conn, "change_plan.json", subscription: subscription)
    end
  end

  swagger_path :cancel_subscription do
    delete("/billing/subscription/cancel")
    summary("Cancel subscription")
    description("Cancels the user's active subscription.")
    response(200, "Subscription cancelled successfully")
    response(404, "Active subscription not found")
  end

  @spec cancel_subscription(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def cancel_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.current_org_id),
         {:ok, _subscription} <- Billing.cancel_subscription(subscription) do
      render(conn, "cancel_subscription.json", subscription: subscription)
    end
  end

  swagger_path :get_invoice do
    get("/billing/subscription/:transaction_id/invoice")
    summary("Generates invoice url of given transaction id")
    description("Returns invoice url to download invoice pdf")
    response(200, "Invoice url generated successfully", Schema.ref(:InvoiceUrl))
    response(404, "Failed to generate invoid url", Schema.ref(:Error))
  end

  @spec get_invoice(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_invoice(conn, params) do
    with {:ok, url} <- PaddleApi.get_invoice_pdf(params["transaction_id"]) do
      render(conn, "invoice.json", invoice_url: url)
    end
  end

  swagger_path :get_subscription_history do
    get("/billing/subscription/history")
    summary("Returns all subscription history under an organisation")
    description("Returns all subscription history under an organisation")

    parameter(:organisation_id, :path, :string, "organisation id", required: true)

    response(200, "Subscription history retrieved successfully", Schema.ref(:SubscriptionHistory))
    response(404, "Subscription history not found")
  end

  def subscription_history_index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: subscription_histories,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Billing.subscription_index(current_user, params) do
      render(conn, "subscription_history_index.json",
        subscription_histories: subscription_histories,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :get_transactions do
    get("/billing/subscription/{organisation_id}/transactions")
    summary("Returns all transaction under an organisation")
    description("Returns all transaction under an organisation")
    response(200, "", Schema.ref(:Transactions))
    response(404, "Failed to fetch transactions", Schema.ref(:Error))
  end

  @spec get_transactions(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_transactions(conn, %{"organisation_id" => organisation_id} = params) do
    with %{
           entries: transactions,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Billing.get_transactions(organisation_id, params) do
      render(conn, "transactions_index.json",
        transactions: transactions,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
