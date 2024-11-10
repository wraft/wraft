defmodule WraftDocWeb.Api.V1.BillingController do
  use WraftDocWeb, :controller

  alias WraftDoc.Billing
  alias WraftDoc.Billing.Subscription

  def get_active_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with %Subscription{} = subscription <- Billing.active_subscription_for(current_user.id) do
      render(conn, "subscription.json", subscription: subscription)
    end
  end

  def ping_subscription(%Plug.Conn{} = conn, _params) do
    current_user = conn.assigns.current_user

    subscribed? = Billing.has_active_subscription?(current_user.id)
    render(conn, "is_subscribed.json", is_subscribed: subscribed?)
  end

  # def choose_plan(conn, _params) do
  #   current_user = conn.assigns.current_user

  #   render(conn, "subscription.json", subscription: subscription)
  # end

  def change_plan_preview(conn, %{"plan_id" => new_plan_id}) do
    current_user = conn.assigns.current_user

    with %Subscription{} = subscription <- Billing.active_subscription_for(current_user.id),
         {:ok, preview_info} <- Billing.change_plan_preview(subscription, new_plan_id) do
      render(conn, "change_plan_preview.json", preview_info: preview_info)
    end
  end

  def change_plan(conn, %{"new_plan_id" => new_plan_id}) do
    current_user = conn.assigns.current_user

    with %Subscription{} = subscription <- Billing.active_subscription_for(current_user.id),
         {:ok, _subscription} <- Billing.change_plan(subscription, new_plan_id) do
      render(conn, "change_plan_success.json")
    end
  end

  def cancel_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with %Subscription{} = subscription <- Billing.active_subscription_for(current_user.id),
         {:ok, _subscription} <- Billing.cancel_subscription(subscription) do
      render(conn, "cancel_subscription.json")
    end
  end
end
