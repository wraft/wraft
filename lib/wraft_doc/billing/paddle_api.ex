defmodule WraftDoc.Billing.PaddleApi do
  @moduledoc """
  This module helps to interact with paddle APIs.
  """
  use Tesla

  plug Tesla.Middleware.Headers, [
    {"Authorization", "Bearer #{System.get_env("PADDLE_VENDOR_AUTH_CODE")}"},
    {"Content-Type", "application/json"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.BaseUrl, vendors_domain()

  # TODO use transaction paid webhook and add status to subscription

  @doc """
  Retrieves paddle paddle subscription entity.
  """
  @spec get_subscription(binary()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
  def get_subscription(subscription_id) do
    subscription_id
    |> get_subscription_url()
    |> get()
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => subscription_data}}} ->
        {:ok, subscription_data}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Previews plan change.
  """
  @spec update_subscription_preview(binary(), binary()) ::
          {:ok, map()} | {:error, binary()} | {:error, map()}
  def update_subscription_preview(paddle_subscription_id, paddle_price_id) do
    params = %{
      collection_mode: "automatic",
      items: [
        %{
          price_id: paddle_price_id,
          quantity: 1
        }
      ],
      proration_billing_mode: "prorated_immediately",
      on_payment_failure: "prevent_change"
    }

    paddle_subscription_id
    |> preview_update_url()
    |> patch(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Update paddle subscription entity.
  """
  @spec update_subscription(binary(), binary()) ::
          {:ok, map()} | {:error, binary()} | {:error, map()}
  def update_subscription(paddle_subscription_id, paddle_price_id) do
    params = %{
      collection_mode: "automatic",
      items: [
        %{
          price_id: paddle_price_id,
          quantity: 1
        }
      ],
      proration_billing_mode: "prorated_immediately",
      on_payment_failure: "prevent_change"
    }

    paddle_subscription_id
    |> update_subscription_url()
    |> patch(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Cancels paddle subscription entity
  """
  @spec cancel_subscription(binary()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
  def cancel_subscription(paddle_subscription_id) do
    # TODO check effects from when and does it changes db.
    params = %{
      effective_from: "immediately"
    }

    paddle_subscription_id
    |> cancel_subscription_url()
    |> post(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %Tesla.Env{status: 404, body: %{"success" => false, "error" => error}}} ->
        {:error, error}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Create paddle price entity.
  """
  @spec create_price(map()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
  def create_price(params) do
    params = format_price_params(params)

    create_price_url()
    |> post(params)
    |> case do
      {:ok, %Tesla.Env{status: 201, body: %{"data" => price_data}}} ->
        {:ok, price_data}

      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:error, body}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Update paddle price entity.
  """
  @spec update_price(binary(), map()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
  def update_price(paddle_price_id, params) do
    params = format_price_params(params)

    paddle_price_id
    |> update_price_url()
    |> patch(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => price_data}}} ->
        {:ok, price_data}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_price_params(
         %{
           "paddle_product_id" => product_id,
           "description" => description,
           "custom" => %{
             "custom_amount" => custom_amount,
             "custom_period" => custom_period,
             "custom_period_frequency" => frequency
           }
         } = params
       ) do
    %{
      product_id: product_id,
      description: description,
      billing_cycle: %{
        interval: custom_period,
        frequency: String.to_integer(frequency)
      },
      quantity: %{
        minimum: 1,
        maximum: 1
      },
      unit_price: %{
        amount: custom_amount,
        currency_code: "USD"
      },
      custom_data: %{
        creator_id: Map.get(params, "creator_id", nil),
        organisation_id: Map.get(params, "organisation_id", nil)
      }
    }
  end

  defp format_price_params(
         %{
           "description" => description,
           "custom" => %{
             "custom_amount" => custom_amount,
             "custom_period" => custom_period,
             "custom_period_frequency" => frequency
           }
         } = params
       ) do
    %{
      description: description,
      billing_cycle: %{
        interval: custom_period,
        frequency: String.to_integer(frequency)
      },
      quantity: %{
        minimum: 1,
        maximum: 1
      },
      unit_price: %{
        amount: custom_amount,
        currency_code: "USD"
      },
      custom_data: %{
        creator_id: Map.get(params, "creator_id", nil),
        organisation_id: Map.get(params, "organisation_id", nil)
      }
    }
  end

  defp format_price_params(
         %{
           "paddle_product_id" => product_id,
           "description" => description,
           "monthly_amount" => monthly_amount,
           "yearly_amount" => yearly_amount
         } = params
       ) do
    # set in case
    {interval, amount} =
      cond do
        monthly_amount not in [nil, ""] ->
          {"month", monthly_amount}

        yearly_amount not in [nil, ""] ->
          {"year", yearly_amount}

        true ->
          {"unknown", nil}
      end

    %{
      product_id: product_id,
      description: description,
      billing_cycle: %{
        interval: interval,
        frequency: 1
      },
      quantity: %{
        minimum: 1,
        maximum: 1
      },
      unit_price: %{
        amount: amount,
        currency_code: "USD"
      },
      custom_data: %{
        creator_id: Map.get(params, "creator_id", nil),
        organisation_id: Map.get(params, "organisation_id", nil)
      }
    }
  end

  defp format_price_params(
         %{
           "description" => description,
           "monthly_amount" => monthly_amount,
           "yearly_amount" => yearly_amount
         } = params
       ) do
    # set in case
    {interval, amount} =
      cond do
        monthly_amount not in [nil, ""] ->
          {"month", monthly_amount}

        yearly_amount not in [nil, ""] ->
          {"year", yearly_amount}

        true ->
          {"month", monthly_amount}
      end

    %{
      description: description,
      billing_cycle: %{
        interval: interval,
        frequency: 1
      },
      quantity: %{
        minimum: 1,
        maximum: 1
      },
      unit_price: %{
        amount: amount,
        currency_code: "USD"
      },
      custom_data: %{
        creator_id: Map.get(params, "creator_id", nil),
        organisation_id: Map.get(params, "organisation_id", nil)
      }
    }
  end

  @doc """
  Create paddle product entity.
  """
  @spec create_product(map()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
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
    |> case do
      {:ok, %Tesla.Env{status: 201, body: %{"data" => product_data}}} ->
        {:ok, product_data}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Update paddle product entity.
  """
  @spec update_product(binary(), map()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
  def update_product(paddle_product_id, %{"name" => name, "description" => description}) do
    params = %{
      "name" => name,
      "description" => description,
      "tax_category" => "saas",
      "type" => "standard",
      "custom_data" => nil
    }

    paddle_product_id
    |> update_product_url()
    |> patch(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => response}}} ->
        {:ok, response}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Delete paddle product entity.
  """
  @spec delete_product(binary()) :: {:ok, map()} | {:error, binary()} | {:error, map()}
  def delete_product(paddle_product_id) do
    params = %{
      "status" => "archived"
    }

    paddle_product_id
    |> delete_product_url()
    |> patch(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"data" => response}}} ->
        {:ok, response}

      {:ok, %Tesla.Env{status: _status, body: %{"error" => %{"detail" => error_details}}}} ->
        {:error, error_details}

      {:error, error} ->
        {:error, error}
    end
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

  defp vendors_domain do
    if Mix.env() in [:dev, :test] do
      "https://sandbox-api.paddle.com"
    else
      "https://api.paddle.com"
    end
  end
end
