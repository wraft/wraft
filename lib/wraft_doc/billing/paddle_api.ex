defmodule WraftDoc.Billing.PaddleApi do
  @moduledoc """
  This module helps to interact with paddle APIs.
  """
  use Tesla

  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Plan

  plug Tesla.Middleware.Headers, [
    {"Authorization", "Bearer #{Application.get_env(:wraft_doc, :paddle)[:api_key]}"},
    {"Content-Type", "application/json"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.BaseUrl, vendors_domain()

  @doc """
  Retrieves paddle subscription entity.
  """
  @spec get_subscription(String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def get_subscription(subscription_id) do
    subscription_id
    |> get_subscription_url()
    |> get()
    |> get_response()
  end

  @doc """
  Previews plan change.
  """
  @spec update_subscription_preview(String.t(), String.t()) ::
          {:ok, map()} | {:error, String.t() | atom()}
  def update_subscription_preview(paddle_subscription_id, %Plan{
        plan_id: provider_plan_id,
        trial_period: trial_period
      }) do
    params = %{
      collection_mode: "automatic",
      items: [
        %{
          price_id: provider_plan_id,
          quantity: 1
        }
      ]
    }

    params =
      if trial_period != nil do
        Map.put(params, :proration_billing_mode, "do_not_bill")
      else
        Map.put(params, :proration_billing_mode, "prorated_immediately")
      end

    paddle_subscription_id
    |> preview_update_url()
    |> patch(params)
    |> get_response()
  end

  @doc """
  Update paddle subscription entity.
  """
  @spec update_subscription(String.t(), User.t(), Plan.t()) ::
          {:ok, map()} | {:error, String.t() | atom()}
  def update_subscription(
        paddle_subscription_id,
        %User{id: user_id, current_org_id: organisation_id},
        %Plan{id: plan_id, plan_id: provider_plan_id, trial_period: trial_period}
      ) do
    params = %{
      collection_mode: "automatic",
      items: [
        %{
          price_id: provider_plan_id,
          quantity: 1
        }
      ],
      custom_data: %{
        plan_id: plan_id,
        user_id: user_id,
        organisation_id: organisation_id
      }
    }

    params =
      if trial_period != nil do
        Map.put(params, :proration_billing_mode, "do_not_bill")
      else
        Map.put(params, :proration_billing_mode, "prorated_immediately")
      end

    paddle_subscription_id
    |> update_subscription_url()
    |> patch(params)
    |> get_response()
  end

  @doc """
  Cancels paddle subscription entity
  """
  @spec cancel_subscription(String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def cancel_subscription(paddle_subscription_id) do
    params = %{
      effective_from: "immediately"
    }

    paddle_subscription_id
    |> cancel_subscription_url()
    |> post(params)
    |> get_response()
  end

  @doc """
  Activate trailing subscription entity
  """
  @spec activate_trailing_subscription(String.t()) ::
          {:ok, map()} | {:error, String.t() | atom()}
  def activate_trailing_subscription(paddle_subscription_id) do
    paddle_subscription_id
    |> activate_trail_subscription_url()
    |> post(%{})
    |> get_response()
  end

  @doc """
  Create paddle price entity.
  """
  @spec create_price(map()) :: {:ok, map()} | {:error, String.t() | atom()}
  def create_price(params) do
    params = format_price_params(params)

    create_price_url()
    |> post(params)
    |> get_response()
  end

  @doc """
  Update paddle price entity.
  """
  @spec update_price(String.t(), map()) :: {:ok, map()} | {:error, String.t() | atom()}
  def update_price(paddle_price_id, params) do
    params = format_price_params(params)

    paddle_price_id
    |> update_price_url()
    |> patch(params)
    |> get_response()
  end

  defp format_price_params(params) do
    base_params = %{
      description: params["description"],
      quantity: %{
        minimum: 1,
        maximum: 1
      }
    }

    params
    |> get_billing_details()
    |> add_trailing(params)
    |> maybe_add_product_id(params)
    |> Map.merge(base_params)
  end

  defp get_billing_details(%{
         "custom" => %{
           "custom_period" => period,
           "custom_period_frequency" => frequency
         },
         "plan_amount" => plan_amount,
         "currency" => currency
       }) do
    %{
      billing_cycle: %{
        interval: period,
        frequency: String.to_integer(frequency)
      },
      unit_price: %{
        amount: plan_amount,
        currency_code: currency
      }
    }
  end

  defp get_billing_details(%{
         "plan_amount" => plan_amount,
         "currency" => currency,
         "billing_interval" => billing_interval
       })
       when billing_interval != :custom do
    %{
      billing_cycle: %{
        interval: billing_interval,
        frequency: 1
      },
      unit_price: %{
        amount: plan_amount,
        currency_code: currency
      }
    }
  end

  defp add_trailing(params, %{"trial_period" => %{"period" => period, "frequency" => frequency}})
       when period != "" and frequency != "" do
    Map.merge(params, %{
      trial_period: %{
        interval: period,
        frequency: String.to_integer(frequency)
      }
    })
  end

  defp add_trailing(params, %{"trial_period" => _}), do: params

  defp maybe_add_product_id(params, %{"product_id" => product_id}),
    do: Map.put(params, :product_id, product_id)

  defp maybe_add_product_id(params, _), do: params

  @doc """
  Create paddle product entity.
  """
  @spec create_product(map()) :: {:ok, map()} | {:error, String.t() | atom()}
  def create_product(%{"name" => name, "description" => description}) do
    params = %{
      "name" => name,
      "description" => description,
      "tax_category" => "saas",
      "type" => "standard",
      "custom_data" => nil
    }

    create_product_url()
    |> post(params)
    |> get_response()
  end

  @doc """
  Update paddle product entity.
  """
  @spec update_product(String.t(), map()) ::
          {:ok, map()} | {:error, String.t() | atom()}
  def update_product(product_id, %{"name" => name, "description" => description}) do
    params = %{
      "name" => name,
      "description" => description,
      "tax_category" => "saas",
      "type" => "standard",
      "custom_data" => nil
    }

    product_id
    |> update_product_url()
    |> patch(params)
    |> get_response()
  end

  @doc """
  Delete paddle product entity.
  """
  @spec delete_product(String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def delete_product(product_id) do
    params = %{
      "status" => "archived"
    }

    product_id
    |> delete_product_url()
    |> patch(params)
    |> get_response()
  end

  defp get_response(response) do
    case response do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %Tesla.Env{status: 201, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Create checkout url.
  """
  @spec create_checkout_url(Plan.t()) :: {:ok, String.t()} | {:error, String.t() | atom()}
  def create_checkout_url(plan) do
    params = %{
      items: [
        %{
          quantity: 1,
          price_id: plan.plan_id
        }
      ],
      currency_code: plan.currency,
      collection_mode: "manual",
      billing_details: %{
        enable_checkout: true,
        payment_terms: %{
          interval: plan.custom.custom_period,
          frequency: plan.custom.custom_period_frequency
        }
      },
      billing_period: %{
        starts_at: DateTime.to_iso8601(DateTime.utc_now()),
        ends_at: DateTime.to_iso8601(plan.custom.end_date)
      },
      custom_data: %{
        plan_id: plan.id,
        organisation_id: plan.organisation_id
      }
    }

    create_transaction_url()
    |> post(params)
    |> get_response()
    |> case do
      {:ok, %{"checkout" => %{"url" => url}}} ->
        {:ok, url}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get invoice PDFs url.
  """
  @spec get_invoice_pdf(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def get_invoice_pdf(transaction_id) do
    transaction_id
    |> get_invoice_pdf_url()
    |> get()
    |> get_response()
    |> case do
      {:ok, %{"url" => url}} ->
        {:ok, url}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Creates coupon in provider.
  """
  @spec create_coupon(map()) :: {:ok, map()} | {:error, String.t() | atom()}
  def create_coupon(params) do
    params = prepare_coupon_params(params)

    create_coupon_url()
    |> post(params)
    |> get_response()
  end

  @doc """
  Update coupon in provider.
  """
  @spec update_coupon(String.t(), map()) :: {:ok, map()} | {:error, String.t() | atom()}
  def update_coupon(coupon_id, params) do
    params = prepare_coupon_params(params)

    coupon_id
    |> update_coupon_url()
    |> patch(params)
    |> get_response()
  end

  @doc """
  Delete coupon in provider.
  """
  @spec delete_coupon(String.t()) :: {:ok, map()} | {:error, String.t() | atom()}
  def delete_coupon(coupon_id) do
    params = %{
      "status" => "archived"
    }

    coupon_id
    |> update_coupon_url()
    |> patch(params)
    |> get_response()
  end

  defp prepare_coupon_params(
         %{
           type: type,
           description: description,
           amount: amount
         } = params
       ) do
    %{
      "description" => description,
      "type" => type,
      "amount" => amount,
      "currency_code" => Map.get(params, :currency, "USD"),
      "code" => Map.get(params, :coupon_code),
      "expires_at" => Map.get(params, :expiry_date),
      "recur" => Map.get(params, :recurring, false),
      "maximum_recurring_intervals" => Map.get(params, :maximum_recurring_intervals, nil),
      "enabled_for_checkout" => true,
      "usage_limit" => Map.get(params, :usage_limit, nil)
    }
  end

  defp create_price_url do
    Path.join(vendors_domain(), "/prices")
  end

  defp update_price_url(price_id) do
    Path.join(vendors_domain(), "/prices/#{price_id}")
  end

  defp create_product_url do
    Path.join(vendors_domain(), "/products")
  end

  defp update_product_url(product_id) do
    Path.join(vendors_domain(), "/products/#{product_id}")
  end

  defp delete_product_url(product_id) do
    Path.join(vendors_domain(), "/products/#{product_id}")
  end

  defp preview_update_url(subscription_id) do
    Path.join(vendors_domain(), "/subscriptions/#{subscription_id}/preview")
  end

  defp update_subscription_url(subscription_id) do
    Path.join(vendors_domain(), "/subscriptions/#{subscription_id}")
  end

  defp cancel_subscription_url(subscription_id) do
    Path.join(vendors_domain(), "/subscriptions/#{subscription_id}/cancel")
  end

  defp get_subscription_url(subscription_id) do
    Path.join(vendors_domain(), "/subscriptions/#{subscription_id}")
  end

  defp activate_trail_subscription_url(subscription_id) do
    Path.join(vendors_domain(), "/subscriptions/#{subscription_id}/activate")
  end

  defp create_transaction_url do
    Path.join(vendors_domain(), "/transactions")
  end

  defp get_invoice_pdf_url(transaction_id) do
    Path.join(vendors_domain(), "/transactions/#{transaction_id}/invoice")
  end

  defp create_coupon_url do
    Path.join(vendors_domain(), "/discounts")
  end

  defp update_coupon_url(coupon_id) do
    Path.join(vendors_domain(), "/discounts/#{coupon_id}")
  end

  defp vendors_domain, do: Application.get_env(:wraft_doc, :paddle)[:base_url]
end
