defmodule WraftDocWeb.Api.V1.BillingController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    change_plan_preview: "payment:show",
    change_plan: "payment:show",
    activate_trial_subscription: "payment:show",
    cancel_subscription: "payment:show",
    get_invoice: "payment:show",
    subscription_history_index: "payment:show",
    get_transactions: "payment:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Billing
  alias WraftDoc.Billing.PaddleApi
  alias WraftDoc.Billing.Subscription
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Plan

  # TODO add RBAC.
  # TODO add pause and resume subscription API.

  alias WraftDocWeb.Schemas

  tags(["Billing"])

  operation(:get_active_subscription,
    summary: "Retrieve active subscription",
    description: "Fetches the current active subscription for the logged-in user.",
    responses: [
      ok:
        {"Active subscription retrieved successfully", "application/json",
         Schemas.Billing.Subscription},
      bad_request: {"Failed to fetch active subscription", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: "Not Found"
    ]
  )

  @spec get_active_subscription(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_active_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.active_subscription_for(current_user.current_org_id) do
      render(conn, "subscription.json", subscription: subscription)
    end
  end

  operation(:get_subscription,
    summary: "Get subscription",
    description: "Gets the current subscription of current organisation",
    responses: [
      ok: {"Subscription", "application/json", Schemas.Billing.Subscription},
      bad_request: {"Failed to fetch subscription", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: "Not Found"
    ]
  )

  @spec get_subscription(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user) do
      render(conn, "subscription.json", subscription: subscription)
    end
  end

  operation(:change_plan_preview,
    summary: "Preview a plan change",
    description: "Provides a preview of subscription changes when switching to a new plan.",
    parameters: [
      plan_id: [in: :path, type: :string, description: "Plan id"]
    ],
    responses: [
      ok:
        {"Change plan preview retrieved successfully", "application/json",
         Schemas.Billing.ChangePlanPreview},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: "Not Found"
    ]
  )

  @spec change_plan_preview(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def change_plan_preview(conn, %{"plan_id" => plan_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user),
         %Plan{} = plan <- Enterprise.get_plan(plan_id),
         {:ok, preview_info} <- Billing.change_plan_preview(subscription, plan) do
      render(conn, "change_plan_preview.json", preview_info: preview_info)
    end
  end

  operation(:change_plan,
    summary: "Change subscription plan",
    description: "Applies a new plan to the user's current subscription.",
    parameters: [
      plan_id: [in: :path, type: :string, description: "Plan id"]
    ],
    responses: [
      ok: {"Plan changed successfully", "application/json", Schemas.Billing.ChangePlan},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec change_plan(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def change_plan(conn, %{"plan_id" => plan_id}) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user),
         %Plan{} = plan <- Enterprise.get_plan(plan_id),
         {:ok, _subscription} <- Billing.change_plan(subscription, current_user, plan) do
      render(conn, "change_plan.json", subscription: subscription)
    end
  end

  operation(:activate_trial_subscription,
    summary: "Activate trial subscription",
    description: "Activates the trial subscription for the current user.",
    responses: [
      ok:
        {"Trial subscription activated successfully", "application/json",
         Schemas.Billing.ActivateTrialSubscription},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: "Not Found"
    ]
  )

  @spec activate_trial_subscription(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def activate_trial_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user),
         {:ok, subscription} <- Billing.activate_trial_subscription(subscription) do
      render(conn, "activate_trial_subscription.json", subscription: subscription)
    end
  end

  operation(:cancel_subscription,
    summary: "Cancel subscription",
    description: "Cancels the user's active subscription.",
    responses: [
      ok:
        {"Subscription cancelled successfully", "application/json",
         Schemas.Billing.CancelSubscription},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: "Not Found"
    ]
  )

  @spec cancel_subscription(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def cancel_subscription(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, %Subscription{} = subscription} <-
           Billing.get_subscription(current_user),
         {:ok, _subscription} <- Billing.cancel_subscription(subscription) do
      render(conn, "cancel_subscription.json", subscription: subscription)
    end
  end

  operation(:get_invoice,
    summary: "Generates invoice url of given transaction id",
    description: "Returns invoice url to download invoice pdf",
    parameters: [
      transaction_id: [in: :path, type: :string, description: "Transaction id", required: true]
    ],
    responses: [
      ok: {"Invoice url generated successfully", "application/json", Schemas.Billing.InvoiceUrl},
      bad_request: {"Failed to generate invoid url", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec get_invoice(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_invoice(conn, params) do
    with {:ok, url} <- PaddleApi.get_invoice_pdf(params["transaction_id"]) do
      render(conn, "invoice.json", invoice_url: url)
    end
  end

  operation(:subscription_history_index,
    summary: "Returns all subscription history under an organisation",
    description: "Returns all subscription history under an organisation",
    parameters: [
      organisation_id: [in: :path, type: :string, description: "organisation id", required: true],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok:
        {"Subscription history retrieved successfully", "application/json",
         Schemas.Billing.SubscriptionHistories},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: "Not Found"
    ]
  )

  def subscription_history_index(conn, %{"organisation_id" => organisation_id} = params) do
    with %{
           entries: subscription_histories,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Billing.subscription_index(organisation_id, params) do
      render(conn, "subscription_history_index.json",
        subscription_histories: subscription_histories,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:get_transactions,
    summary: "Returns all transaction under an organisation",
    description: "Returns all transaction under an organisation",
    parameters: [
      organisation_id: [in: :path, type: :string, description: "Organisation id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Billing.Transactions},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      bad_request: {"Failed to fetch transactions", "application/json", Schemas.Error}
    ]
  )

  @spec get_transactions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_transactions(conn, %{"organisation_id" => organisation_id} = params) do
    with %{
           entries: transactions,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Billing.get_transactions(organisation_id, params) do
      render(conn, "transactions_index.json",
        transactions: transactions,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
