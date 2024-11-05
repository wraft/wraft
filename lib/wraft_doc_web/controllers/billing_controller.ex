defmodule WraftDocWeb.Api.V1.BillingController do
  use WraftDocWeb, :controller

  def choose_plan(conn, _params) do
    render(conn, "choose_plan.json")
  end

  def change_plan(conn, _params) do
    render(conn, "change_plan.json")
  end

  def upgrade_subscription(conn, _params) do
    render(conn, "upgrade_subscription.json")
  end

  def cancel_subscription(conn, _params) do
    render(conn, "cancel_subscription.json")
  end

  def get_active_subscription(conn, _params) do
    render(conn, "get_active_subscription.json")
  end
end
