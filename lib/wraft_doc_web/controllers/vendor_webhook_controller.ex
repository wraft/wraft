defmodule WraftDocWeb.Api.V1.VendorsWebhookController do
  use WraftDocWeb, :controller
  require Logger

  alias WraftDoc.Billing

  # TODO: implement signature verification

  def webhook(conn, %{"event_type" => "subscription.created", "data" => params}) do
    params
    |> Billing.subscription_created()
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"event_type" => "subscription.updated", "data" => params}) do
    params
    |> Billing.subscription_updated()
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"event_type" => "subscription.canceled", "data" => params}) do
    params
    |> Billing.subscription_cancelled()
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"event_type" => "subscription_payment_succeeded", "data" => params}) do
    params
    |> Billing.subscription_payment_succeeded()
    |> webhook_response(conn, params)
  end

  def webhook(conn, _params) do
    conn |> send_resp(404, "") |> halt
  end

  defp webhook_response({:ok, _}, conn, _params) do
    send_resp(conn, 200, "")
  end

  defp webhook_response({:error, details}, conn, _params) do
    Logger.error("Error processing Paddle webhook: #{inspect(details)}")

    conn |> send_resp(400, "") |> halt
  end
end
