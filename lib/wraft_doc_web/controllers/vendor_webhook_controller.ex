defmodule WraftDocWeb.Api.V1.VendorsWebhookController do
  use WraftDocWeb, :controller
  require Logger

  alias WraftDoc.Billing

  # plug :verify_signature when action in [:webhook]

  # @paddle_prod_key File.read!("priv/paddle.pem")
  # @paddle_sandbox_key File.read!("priv/paddle_sandbox.pem")

  def webhook(conn, %{"alert_name" => "subscription_created"} = params) do
    params
    |> Billing.subscription_created()
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_updated"} = params) do
    params
    |> Billing.subscription_updated()
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_cancelled"} = params) do
    params
    |> Billing.subscription_cancelled()
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_payment_succeeded"} = params) do
    params
    |> Billing.subscription_payment_succeeded()
    |> webhook_response(conn, params)
  end

  def webhook(conn, _params) do
    conn |> send_resp(404, "") |> halt
  end

  # def verify_signature(conn, _opts) do
  #   signature = Base.decode64!(conn.params["p_signature"])

  #   msg =
  #     Map.delete(conn.params, "p_signature")
  #     |> Enum.map(fn {key, val} -> {key, "#{val}"} end)
  #     |> List.keysort(0)
  #     |> PhpSerializer.serialize()

  #   [key_entry] = :public_key.pem_decode(get_paddle_key())

  #   public_key = :public_key.pem_entry_decode(key_entry)

  #   if :public_key.verify(msg, :sha, signature, public_key) do
  #     conn
  #   else
  #     send_resp(conn, 400, "") |> halt
  #   end
  # end

  # defp get_paddle_key do
  #   if Application.get_env(:plausible, :environment) in ["dev", "staging"] do
  #     @paddle_sandbox_key
  #   else
  #     @paddle_prod_key
  #   end
  # end

  defp webhook_response({:ok, _}, conn, _params) do
    send_resp(conn, 200, "")
  end

  defp webhook_response({:error, details}, conn, _params) do
    Logger.error("Error processing Paddle webhook: #{inspect(details)}")

    conn |> send_resp(400, "") |> halt
  end
end
