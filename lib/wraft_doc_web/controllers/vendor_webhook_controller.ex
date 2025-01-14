defmodule WraftDocWeb.Api.V1.VendorsWebhookController do
  use WraftDocWeb, :controller
  require Logger

  alias WraftDoc.Billing

  plug :verify_signature when action in [:webhook]

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
    %{"ts" => timestamp, "h1" => received_signature} = parse_signature_header(conn)

    conn
    |> build_signed_payload(timestamp)
    |> compute_signature()
    |> case do
      {:ok, computed_signature} ->
        if Plug.Crypto.secure_compare(received_signature, computed_signature) do
          conn
        else
          error_response(conn, 403, "You are not authorized for this action!")
        end

      {:error, error} ->
        error_response(conn, 400, error)
    end

    # rescue
    #   {:error, error} ->
    #     error_response(conn, 401, error)
  end

  defp error_response(conn, status_code, error) do
    body = Jason.encode!(%{errors: error})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status_code, body)
    |> halt()
  end

  defp parse_signature_header(conn) do
    conn.req_headers
    |> List.keyfind("paddle-signature", 0)
    |> case do
      nil ->
        {:error, "Missing paddle-signature header"}

      {_, header_value} ->
        header_value
        |> String.split(";")
        |> Enum.map(fn item ->
          [key, value] = String.split(item, "=", parts: 2)
          {String.trim(key), String.trim(value)}
        end)
        |> Enum.into(%{})
        |> then(fn %{"ts" => _, "h1" => _} = parsed -> parsed end)
    end
  end

  defp build_signed_payload(conn, timestamp) do
    :raw_body
    |> then(&conn.private[&1])
    |> then(&"#{timestamp}:#{&1}")
  end

  defp compute_signature(signed_payload) do
    :crypto.mac(:hmac, :sha256, webhook_secret_key(), signed_payload)
    |> Base.encode16(case: :lower)
    |> then(&{:ok, &1})
  end

  def webhook_secret_key do
    Application.get_env(:wraft_doc, :paddle_webhook_secret)
  end
end
