defmodule WraftDocWeb.Api.V1.VendorsWebhookController do
  use WraftDocWeb, :controller
  require Logger

  alias WraftDoc.Billing

  plug :verify_signature when action in [:webhook]

  @webhook_secret_key System.get_env("PADDLE_WEBHOOK_SECRET_KEY")

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

  # may need to implement for notifications
  # def webhook(conn, %{"event_type" => "subscription_payment_succeeded", "data" => params}) do
  #   params
  #   |> Billing.subscription_payment_succeeded()
  #   |> webhook_response(conn, params)
  # end

  def webhook(conn, %{"event_type" => "transaction.completed", "data" => params}) do
    params
    |> Billing.subscription_cancelled()
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

  def verify_signature(conn, _opts) do
    %{"ts" => timestamp, "h1" => recieved_signature} = parse_signature_header(conn)

    {:ok, computed_signature} =
      conn
      |> build_signed_payload(timestamp)
      |> compute_signature()

    recieved_signature
    |> Plug.Crypto.secure_compare(computed_signature)
    |> case do
      true ->
        conn

      _ ->
        body = Jason.encode!(%{errors: "You are not authorized for this action.!"})
        conn |> put_resp_content_type("application/json") |> send_resp(403, body)
    end
  end

  defp parse_signature_header(conn) do
    conn.req_headers
    |> List.keyfind("paddle-signature", 0)
    |> elem(1)
    |> String.split(";")
    |> Enum.map(fn item ->
      [key, value] = String.split(item, "=", parts: 2)
      {String.trim(key), String.trim(value)}
    end)
    |> Enum.into(%{})
  end

  defp build_signed_payload(conn, timestamp) do
    :raw_body
    |> then(&conn.private[&1])
    |> then(&"#{timestamp}:#{&1}")
  end

  defp compute_signature(signed_payload) do
    signed_payload
    |> then(&:crypto.mac(:hmac, :sha256, @webhook_secret_key, &1))
    |> Base.encode16(case: :lower)
    |> then(&{:ok, &1})
  end
end
