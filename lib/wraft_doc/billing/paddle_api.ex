defmodule WraftDoc.Billing.PaddleApi do
  @moduledoc """
  Paddle API.
  """
  use Tesla

  # Define Tesla client with middleware
  plug Tesla.Middleware.Headers, [{"Content-Type", "application/json"}]
  plug Tesla.Middleware.JSON
  # plug Tesla.Middleware.BaseUrl, "https://vendors.paddle.com"

  # @headers [
  #   {"content-type", "application/json"},
  #   {"accept", "application/json"}
  # ]
  @paddle_vendor_id System.get_env("PADDLE_VENDOR_ID")
  @paddle_api_key System.get_env("PADDLE_API_KEY")

  # may move to account module
  # defp get_user_email(user_id) do
  #   Account.get_user_by_uuid(user_id).email
  # end

  def get_subscription(subscription_id) do
    params = %{
      "vendor_id" => @paddle_vendor_id,
      "vendor_auth_code" => @paddle_api_key,
      "subscription_id" => subscription_id
    }

    get_subscription_url()
    |> post(URI.encode_query(params))
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"success" => true, "response" => subscription_data}} ->
            {:ok, subscription_data}

          {:ok, %{"success" => false, "error" => error}} ->
            {:error, error}

          {:error, decode_error} ->
            {:error, decode_error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_subscription_preview(paddle_subscription_id, new_plan_id) do
    params = %{
      vendor_id: @paddle_vendor_id,
      vendor_auth_code: @paddle_api_key,
      subscription_id: paddle_subscription_id,
      plan_id: new_plan_id,
      prorate: true,
      keep_modifiers: true,
      bill_immediately: true,
      quantity: 1
    }

    preview_update_url()
    |> post(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"success" => true, "response" => response}}} ->
        {:ok, response}

      {:ok, %Tesla.Env{status: 200, body: %{"success" => false, "error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_subscription(paddle_subscription_id, params) do
    params =
      Map.merge(params, %{
        vendor_id: @paddle_vendor_id,
        vendor_auth_code: @paddle_api_key,
        subscription_id: paddle_subscription_id,
        prorate: true,
        keep_modifiers: true,
        bill_immediately: true,
        quantity: 1
      })

    update_subscription_url()
    |> post(params)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: %{"success" => true, "response" => response}}} ->
        {:ok, response}

      {:ok, %Tesla.Env{status: 200, body: %{"success" => false, "error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def vendors_domain do
    if Mix.env() in [:dev, :test] do
      "https://sandbox-vendors.paddle.com"
    else
      "https://vendors.paddle.com"
    end
  end

  def checkout_domain do
    if Mix.env() in [:dev, :test] do
      "https://sandbox-checkout.paddle.com"
    else
      "https://checkout.paddle.com"
    end
  end

  defp preview_update_url do
    Path.join(vendors_domain(), "/api/2.0/subscription/preview_update")
  end

  defp update_subscription_url do
    Path.join(vendors_domain(), "/api/2.0/subscription/users/update")
  end

  defp get_subscription_url do
    Path.join(vendors_domain(), "/api/2.0/subscription/users")
  end

  # defp create_checkout_url do
  #   Path.join(checkout_domain(), "/api/2.0/product/generate_pay_link")
  # end

  # defp prices_url() do
  #   Path.join(checkout_domain(), "/api/2.0/prices")
  # end
end
