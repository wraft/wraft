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
            id(:string, "Subscription ID")
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

          example(%{
            id: "4296a052-e147-491b-84cf-9931e4776410",
            provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
            provider_plan_id: "pri_01jj19s7ev25a4a1m3b6efbpgd",
            provider: "paddle",
            status: "active",
            type: "regular",
            current_period_start: "2025-01-20T19:18:01Z",
            current_period_end: "2025-02-20T19:18:01Z",
            canceled_at: nil,
            next_payment_date: "2025-02-20",
            next_bill_amount: 467,
            currency: "INR",
            organisation_id: "a19aadca-7655-40e7-9647-0a2bd49d20cc",
            user_id: "b0c5cfc9-bdd4-4809-898f-d75e6b95e719",
            plan_id: "5932900c-8d9a-4493-95f9-96375032cabc",
            transaction_id: "txn_01jj2jd17gg4n3j1k71zm6eatv",
            update_url: nil,
            cancel_url: nil
          })
        end,
      InvoiceUrl:
        swagger_schema do
          title("Invoice url")
          description("The url for invoice pdf.")

          properties do
            invoice_url(:string, "Invoice url")
          end
        end,
      ChangePlan:
        swagger_schema do
          title("Plan Change")
          description("plan change")

          properties do
            message(:string, "message of plan change")

            subscription(
              Schema.ref(:Subscription),
              "active subscription"
            )
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
      CancelSubscription:
        swagger_schema do
          title("Cancel Subscription")
          description("Cancel subscription")

          properties do
            message(:string, "message of cancel subscription")

            subscription(
              Schema.ref(:Subscription),
              "active subscription"
            )
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
      SubscriptionHistories:
        swagger_schema do
          title("Subscription History")
          description("Subscription history details")

          properties do
            subscription_history(Schema.ref(:SubscriptionHistory))
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
            id(:string, "Subscription history ID")
            provider_subscription_id(:string, "Subscription ID")
            user_id(:string, "User ID")
            organisation_id(:string, "Organization ID")
            plan_id(:string, "Plan ID")
            amount(:string, "amount")
            plan_name(:string, "plan name")
            event_type(:string, "event type")
            transaction_id(:string, "transaction id")

            current_subscription_start(
              :string,
              "Subscription creation date. Format: ISO8601 datetime"
            )

            current_subscription_end(
              :string,
              "Subscription update date. Format: ISO8601 datetime"
            )
          end
        end
    }
  end

  swagger_path :get_active_subscription do
    get("/billing/subscription/active")
    summary("Retrieve active subscription")
    description("Fetches the current active subscription for the logged-in user.")

    response(200, "Active subscription retrieved successfully", Schema.ref(:Subscription))
    response(400, "Failed to fetch active subscription", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "not found")
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
    get("/billing/subscription")
    summary("Get subscription")
    description("Gets the current subscription of current organisation")

    response(200, "Subscription", Schema.ref(:Subscription))
    response(400, "Failed to fetch subscription", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "not found")
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
    post("/billing/change-plan/preview/{plan_id}")
    summary("Preview a plan change")
    description("Provides a preview of subscription changes when switching to a new plan.")

    consumes("multipart/form-data")

    parameter(:plan_id, :path, :string, "Plan id")

    response(200, "Change plan preview retrieved successfully", Schema.ref(:ChangePlanPreview))
    response(400, "", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "not found")
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
    post("/billing/change-plan/{plan_id}")
    summary("Change subscription plan")
    description("Applies a new plan to the user's current subscription.")

    consumes("multipart/form-data")

    parameter(:plan_id, :path, :string, "Plan id")

    response(200, "Plan changed successfully", Schema.ref(:ChangePlan))
    response(400, "", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "not found", Schema.ref(:Error))
  end

  @spec change_plan(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def change_plan(conn, %{"plan_id" => plan_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user),
         {:ok, _subscription} <- Billing.change_plan(subscription, plan_id) do
      render(conn, "change_plan.json", subscription: subscription)
    end
  end

  swagger_path :cancel_subscription do
    delete("/billing/subscription/cancel")
    summary("Cancel subscription")
    description("Cancels the user's active subscription.")

    response(200, "Subscription cancelled successfully", Schema.ref(:CancelSubscription))
    response(400, "", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "not found")
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
    get("/billing/subscription/{transaction_id}/invoice")
    summary("Generates invoice url of given transaction id")
    description("Returns invoice url to download invoice pdf")

    parameters do
      transaction_id(:path, :string, "Transaction id", required: true)
    end

    response(200, "Invoice url generated successfully", Schema.ref(:InvoiceUrl))
    response(400, "Failed to generate invoid url", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
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

    parameter(:organisation_id, :formData, :string, "organisation id", required: true)

    response(
      200,
      "Subscription history retrieved successfully",
      Schema.ref(:SubscriptionHistories)
    )

    response(400, "", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "not found")
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

    parameters do
      organisation_id(:path, :string, "Organisation id", required: true)
    end

    response(200, "", Schema.ref(:Transactions))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Failed to fetch transactions", Schema.ref(:Error))
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
