defmodule WraftDocWeb.Schemas.Billing do
  @moduledoc """
  Schema for Billing request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Subscription do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Subscription",
      description: "A user's subscription details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Subscription ID"},
        provider_subscription_id: %Schema{
          type: :string,
          description: "Provider's subscription ID"
        },
        provider_plan_id: %Schema{type: :string, description: "Provider's plan ID"},
        provider: %Schema{type: :string, description: "Subscription provider name"},
        status: %Schema{type: :string, description: "Current subscription status"},
        start_date: %Schema{type: :string, description: "Format: ISO8601 datetime"},
        end_date: %Schema{type: :string, description: "Format: ISO8601 datetime"},
        next_bill_date: %Schema{
          type: :string,
          description: "Next billing date. Format: ISO8601 datetime"
        },
        next_bill_amount: %Schema{type: :number, description: "Amount of next bill"},
        currency: %Schema{type: :string, description: "Currency code"},
        organisation_id: %Schema{type: :string, description: "Organization ID"},
        subscriber_id: %Schema{type: :string, description: "User ID"},
        plan_id: %Schema{type: :string, description: "Plan ID"}
      },
      example: %{
        id: "4296a052-e147-491b-84cf-9931e4776410",
        provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
        provider_plan_id: "pri_01jj19s7ev25a4a1m3b6efbpgd",
        status: "active",
        type: "regular",
        start_date: "2025-01-20T19:18:01Z",
        end_date: "2025-02-20T19:18:01Z",
        next_payment_date: "2025-02-20",
        next_bill_amount: 467,
        currency: "INR",
        organisation_id: "a19aadca-7655-40e7-9647-0a2bd49d20cc",
        subscriber_id: "b0c5cfc9-bdd4-4809-898f-d75e6b95e719",
        plan_id: "5932900c-8d9a-4493-95f9-96375032cabc",
        transaction_id: "txn_01jj2jd17gg4n3j1k71zm6eatv"
      }
    })
  end

  defmodule InvoiceUrl do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Invoice url",
      description: "The url for invoice pdf.",
      type: :object,
      properties: %{
        invoice_url: %Schema{type: :string, description: "Invoice url"}
      }
    })
  end

  defmodule ChangePlan do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Plan Change",
      description: "plan change",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "message of plan change"},
        subscription: %Schema{anyOf: [Subscription], description: "active subscription"}
      }
    })
  end

  defmodule BillingCycle do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Billing Cycle",
      description: "Billing cycle details",
      type: :object,
      properties: %{
        frequency: %Schema{type: :integer, description: "Billing frequency"},
        interval: %Schema{type: :string, description: "Billing interval (e.g., month, year)"}
      }
    })
  end

  defmodule BillingPeriod do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Billing Period",
      description: "Start and end dates for billing period",
      type: :object,
      properties: %{
        starts_at: %Schema{
          type: :string,
          description: "Period start date. Format: ISO8601 datetime"
        },
        ends_at: %Schema{type: :string, description: "Period end date. Format: ISO8601 datetime"}
      }
    })
  end

  defmodule TransactionTotals do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Transaction Totals",
      description: "Breakdown of transaction amounts",
      type: :object,
      properties: %{
        subtotal: %Schema{type: :number, description: "Subtotal amount"},
        tax: %Schema{type: :number, description: "Tax amount"},
        total: %Schema{type: :number, description: "Total amount"}
      }
    })
  end

  defmodule ProductDetail do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Product Detail",
      description: "Details about a product in the subscription",
      type: :object,
      properties: %{
        product_name: %Schema{type: :string, description: "Name of the product"},
        description: %Schema{type: :string, description: "Product description"},
        subtotal: %Schema{type: :number, description: "Product subtotal"},
        tax: %Schema{type: :number, description: "Product tax"},
        total: %Schema{type: :number, description: "Product total"}
      }
    })
  end

  defmodule ManagementUrls do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Management URLs",
      description: "URLs for managing the subscription",
      type: :object,
      properties: %{
        update_payment_method: %Schema{type: :string, description: "URL to update payment method"},
        cancel: %Schema{type: :string, description: "URL to cancel subscription"}
      }
    })
  end

  defmodule ChangePlanPreview do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Plan Change Preview",
      description: "Preview information for a plan change",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Status of the preview"},
        currency_code: %Schema{type: :string, description: "Currency code for billing"},
        billing_cycle: %Schema{anyOf: [BillingCycle], description: "Billing cycle information"},
        current_billing_period: %Schema{
          anyOf: [BillingPeriod],
          description: "Current billing period"
        },
        recurring_transaction_totals: %Schema{
          anyOf: [TransactionTotals],
          description: "Recurring transaction amounts"
        },
        next_billed_at: %Schema{
          type: :string,
          description: "Next billing date. Format: ISO8601 datetime"
        },
        product_details: %Schema{
          type: :array,
          description: "List of product details",
          items: ProductDetail
        },
        management_urls: %Schema{anyOf: [ManagementUrls], description: "Management URLs"}
      }
    })
  end

  defmodule CancelSubscription do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Cancel Subscription",
      description: "Cancel subscription",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "message of cancel subscription"},
        subscription: %Schema{anyOf: [Subscription], description: "active subscription"}
      }
    })
  end

  defmodule Transaction do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Transaction",
      description: "Transaction details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Transaction ID"},
        user_id: %Schema{type: :string, description: "User ID"},
        org_id: %Schema{type: :string, description: "Organization ID"},
        amount: %Schema{type: :number, description: "Transaction amount"},
        currency: %Schema{type: :string, description: "Transaction currency"},
        description: %Schema{type: :string, description: "Transaction description"},
        created_at: %Schema{
          type: :string,
          description: "Transaction creation date. Format: ISO8601 datetime"
        },
        updated_at: %Schema{
          type: :string,
          description: "Transaction update date. Format: ISO8601 datetime"
        },
        status: %Schema{type: :string, description: "Transaction status"},
        type: %Schema{type: :string, description: "Transaction type"},
        payment_method: %Schema{
          type: :string,
          description: "Payment method used for the transaction"
        },
        payment_method_details: %Schema{
          type: :string,
          description: "Details about the payment method"
        }
      }
    })
  end

  defmodule Transactions do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Transaction",
      description: "Transaction details",
      type: :object,
      properties: %{
        transactions: %Schema{type: :array, items: Transaction},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      }
    })
  end

  defmodule SubscriptionHistory do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Subscription History",
      description: "Subscription history details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Subscription history ID"},
        provider_subscription_id: %Schema{type: :string, description: "Subscription ID"},
        user_id: %Schema{type: :string, description: "User ID"},
        organisation_id: %Schema{type: :string, description: "Organization ID"},
        plan_id: %Schema{type: :string, description: "Plan ID"},
        amount: %Schema{type: :string, description: "amount"},
        plan_name: %Schema{type: :string, description: "plan name"},
        event_type: %Schema{type: :string, description: "event type"},
        transaction_id: %Schema{type: :string, description: "transaction id"},
        current_subscription_start: %Schema{
          type: :string,
          description: "Subscription creation date. Format: ISO8601 datetime"
        },
        current_subscription_end: %Schema{
          type: :string,
          description: "Subscription update date. Format: ISO8601 datetime"
        }
      }
    })
  end

  defmodule SubscriptionHistories do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Subscription History",
      description: "Subscription history details",
      type: :object,
      properties: %{
        subscription_history: %Schema{type: :array, items: SubscriptionHistory},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      }
    })
  end

  defmodule ActivateTrialSubscription do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Activate Trial Subscription",
      description: "Activate Trial Subscription",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "message of activate trial subscription"},
        subscription: %Schema{anyOf: [Subscription]}
      }
    })
  end
end
