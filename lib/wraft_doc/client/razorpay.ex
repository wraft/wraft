defmodule WraftDoc.Client.Razorpay do
  @moduledoc """
    A module to handle razorpay payments with https://razorpay.com/
  """
  require Logger

  use Tesla, only: [:get]

  @razorpay_base_url Application.compile_env!(:wraft_doc, [__MODULE__, :base_url])
  @razorpay_client Application.compile_env(:wraft_doc, [:test_module, :razorpay], __MODULE__)

  plug Tesla.Middleware.BaseUrl, @razorpay_base_url

  plug Tesla.Middleware.Headers, [
    {"content-type", "application/json; charset=utf-8"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger

  @spec get_payment(binary()) :: {:ok, map()} | {:error, map()}
  def get_payment(payment_id) do
    "/#{payment_id}"
    |> get(headers: [{"Authorization", basic_auth_header()}])
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        Logger.info("Payment details succcessfully retrieved", status: 200)
        {:ok, body}

      {:ok, %Tesla.Env{status: status, body: %{"error" => error}}} ->
        Logger.error("Unable to retrieve payment details", error: error, status: status)
        {:error, error}
    end
  end

  defp basic_auth_header do
    "Basic " <> Base.encode64("#{api_key()}:#{secret_key()}")
  end

  defp api_key, do: Application.get_env(:wraft_doc, [__MODULE__, :api_key])
  defp secret_key, do: Application.get_env(:wraft_doc, [__MODULE__, :secret_key])
  def client, do: @razorpay_client
end

defmodule WraftDoc.Client.Razorpay.Behaviour do
  @moduledoc false
  @callback get_payment(binary()) :: {:ok, map()} | {:error, map()}
end
