defmodule WraftDocWeb.Schemas.Billing do
  @moduledoc """
  Schema for Billing request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.{Coupon, Organisation, Plan, User}

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
        transaction_id: %Schema{type: :string, description: "Transaction ID"},
        status: %Schema{type: :string, description: "Current subscription status"},
        start_date: %Schema{type: :string, description: "Format: ISO8601 datetime"},
        end_date: %Schema{type: :string, description: "Format: ISO8601 datetime"},
        next_bill_date: %Schema{
          type: :string,
          description: "Next billing date. Format: ISO8601 datetime"
        },
        next_bill_amount: %Schema{type: :number, description: "Amount of next bill"},
        coupon_id: %Schema{type: :string, description: "Coupon ID"},
        coupon: Coupon.Coupon,
        coupon_start_date: %Schema{type: :string, description: "Coupon start date"},
        coupon_end_date: %Schema{type: :string, description: "Coupon end date"},
        currency: %Schema{type: :string, description: "Currency code"},
        subscriber_id: %Schema{type: :string, description: "User ID"},
        subscriber: User.User,
        organisation_id: %Schema{type: :string, description: "Organization ID"},
        organisation: Organisation.Organisation,
        plan_id: %Schema{type: :string, description: "Plan ID"},
        plan: Plan.Plan
      },
      example: %{
        id: "4296a052-e147-491b-84cf-9931e4776410",
        provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
        provider_plan_id: "pri_01jj19s7ev25a4a1m3b6efbpgd",
        status: "active",
        start_date: "2025-01-20T19:18:01Z",
        end_date: "2025-02-20T19:18:01Z",
        next_bill_date: "2025-02-20",
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
      },
      example: %{
        invoice_url: "https://example.com/invoice.pdf"
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
      },
      example: %{
        message: "Plan changed successfully",
        subscription: %{
          id: "4296a052-e147-491b-84cf-9931e4776410",
          provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
          provider_plan_id: "pri_01jj19s7ev25a4a1m3b6efbpgd",
          status: "active",
          start_date: "2025-01-20T19:18:01Z",
          end_date: "2025-02-20T19:18:01Z",
          next_bill_date: "2025-02-20",
          next_bill_amount: 467,
          currency: "INR",
          organisation_id: "a19aadca-7655-40e7-9647-0a2bd49d20cc",
          subscriber_id: "b0c5cfc9-bdd4-4809-898f-d75e6b95e719",
          plan_id: "5932900c-8d9a-4493-95f9-96375032cabc",
          transaction_id: "txn_01jj2jd17gg4n3j1k71zm6eatv"
        }
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
      },
      example: %{
        frequency: 1,
        interval: "month"
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
      },
      example: %{
        starts_at: "2025-01-01T00:00:00Z",
        ends_at: "2025-02-01T00:00:00Z"
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
        discount: %Schema{type: :number, description: "Discount amount"},
        tax: %Schema{type: :number, description: "Tax amount"},
        total: %Schema{type: :number, description: "Total amount"}
      },
      example: %{
        subtotal: 100.0,
        discount: 0.0,
        tax: 10.0,
        total: 110.0
      }
    })
  end

  defmodule PlanPricing do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Plan Pricing",
      description: "Details about a product pricing in the subscription",
      type: :object,
      properties: %{
        product_name: %Schema{type: :string, description: "Name of the product"},
        description: %Schema{type: :string, description: "Product description"},
        subtotal: %Schema{type: :number, description: "Product subtotal"},
        discount: %Schema{type: :number, description: "Product discount"},
        tax: %Schema{type: :number, description: "Product tax"},
        total: %Schema{type: :number, description: "Product total"}
      },
      example: %{
        product_name: "Pro Plan",
        description: "Monthly subscription",
        subtotal: 100.0,
        discount: 0.0,
        tax: 10.0,
        total: 110.0
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
        plan_pricing: %Schema{
          type: :array,
          description: "List of plan pricing details",
          items: PlanPricing
        }
      },
      example: %{
        status: "active",
        currency_code: "USD",
        billing_cycle: %{frequency: 1, interval: "month"},
        current_billing_period: %{
          starts_at: "2025-01-01T00:00:00Z",
          ends_at: "2025-02-01T00:00:00Z"
        },
        recurring_transaction_totals: %{subtotal: 100.0, discount: 0.0, tax: 10.0, total: 110.0},
        next_billed_at: "2025-02-01T00:00:00Z",
        plan_pricing: [
          %{
            product_name: "Pro Plan",
            description: "Monthly",
            subtotal: 100.0,
            discount: 0.0,
            tax: 10.0,
            total: 110.0
          }
        ]
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
      },
      example: %{
        message: "Subscription cancelled",
        subscription: %{
          id: "4296a052-e147-491b-84cf-9931e4776410",
          provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
          provider_plan_id: "pri_01jj19s7ev25a4a1m3b6efbpgd",
          status: "cancelled",
          start_date: "2025-01-20T19:18:01Z",
          end_date: "2025-02-20T19:18:01Z",
          next_bill_date: "2025-02-20",
          next_bill_amount: 467,
          currency: "INR",
          organisation_id: "a19aadca-7655-40e7-9647-0a2bd49d20cc",
          subscriber_id: "b0c5cfc9-bdd4-4809-898f-d75e6b95e719",
          plan_id: "5932900c-8d9a-4493-95f9-96375032cabc",
          transaction_id: "txn_01jj2jd17gg4n3j1k71zm6eatv"
        }
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
        transaction_id: %Schema{type: :string, description: "Provider Transaction ID"},
        invoice_number: %Schema{type: :string, description: "Invoice Number"},
        invoice_id: %Schema{type: :string, description: "Invoice ID"},
        date: %Schema{type: :string, description: "Transaction date"},
        provider_subscription_id: %Schema{type: :string, description: "Provider Subscription ID"},
        provider_plan_id: %Schema{type: :string, description: "Provider Plan ID"},
        billing_period_start: %Schema{type: :string, description: "Billing Period Start"},
        billing_period_end: %Schema{type: :string, description: "Billing Period End"},
        subtotal_amount: %Schema{type: :number, description: "Subtotal Amount"},
        discount_amount: %Schema{type: :number, description: "Discount Amount"},
        tax: %Schema{type: :number, description: "Tax Amount"},
        total_amount: %Schema{type: :number, description: "Total Amount"},
        currency: %Schema{type: :string, description: "Transaction currency"},
        payment_method: %Schema{type: :string, description: "Payment Method"},
        payment_method_details: %Schema{type: :string, description: "Payment Method Details"},
        coupon_id: %Schema{type: :string, description: "Coupon ID"},
        coupon: Coupon.Coupon,
        subscriber_id: %Schema{type: :string, description: "User ID"},
        subscriber: User.User,
        organisation_id: %Schema{type: :string, description: "Organization ID"},
        organisation: Organisation.Organisation,
        plan_id: %Schema{type: :string, description: "Plan ID"},
        plan: Plan.Plan
      },
      example: %{
        id: "dabc3e2d-10a8-4f8a-a360-8b47f3934968",
        transaction_id: "txn_01jj2jd17gg4n3j1k71zm6eatv",
        invoice_number: "INV-123",
        amount: 110.0,
        currency: "USD",
        status: "success",
        payment_method: "card",
        payment_method_details: "**** 4242"
      }
    })
  end

  defmodule Transactions do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Transactions",
      description: "List of transactions",
      type: :object,
      properties: %{
        transactions: %Schema{type: :array, items: Transaction},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        transactions: [
          %{
            id: "dabc3e2d-10a8-4f8a-a360-8b47f3934968",
            transaction_id: "txn_01jj2jd17gg4n3j1k71zm6eatv",
            amount: 110.0,
            currency: "USD"
          }
        ],
        page_number: 1,
        total_pages: 10,
        total_entries: 100
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
        current_subscription_start: %Schema{
          type: :string,
          description: "Subscription creation date. Format: ISO8601 datetime"
        },
        current_subscription_end: %Schema{
          type: :string,
          description: "Subscription update date. Format: ISO8601 datetime"
        },
        amount: %Schema{type: :string, description: "amount"},
        event_type: %Schema{type: :string, description: "event type"},
        transaction_id: %Schema{type: :string, description: "transaction id"},
        subscriber_id: %Schema{type: :string, description: "User ID"},
        subscriber: User.User,
        organisation_id: %Schema{type: :string, description: "Organization ID"},
        organisation: Organisation.Organisation,
        plan_id: %Schema{type: :string, description: "Plan ID"},
        plan: Plan.Plan
      },
      example: %{
        id: "dabc3e2d-10a8-4f8a-a360-8b47f3934968",
        provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
        amount: "100.00",
        event_type: "created",
        transaction_id: "txn_123",
        current_subscription_start: "2025-01-01T00:00:00Z",
        current_subscription_end: "2025-02-01T00:00:00Z"
      }
    })
  end

  defmodule SubscriptionHistories do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Subscription Histories",
      description: "List of subscription histories",
      type: :object,
      properties: %{
        subscription_histories: %Schema{type: :array, items: SubscriptionHistory},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        subscription_histories: [
          %{
            id: "dabc3e2d-10a8-4f8a-a360-8b47f3934968",
            provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
            amount: "100.00",
            event_type: "created"
          }
        ],
        page_number: 1,
        total_pages: 5,
        total_entries: 50
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
      },
      example: %{
        message: "Trial activated",
        subscription: %{
          id: "4296a052-e147-491b-84cf-9931e4776410",
          provider_subscription_id: "sub_01jj2hnvs63hsbhea7qw6k7m0z",
          status: "active"
        }
      }
    })
  end
end
