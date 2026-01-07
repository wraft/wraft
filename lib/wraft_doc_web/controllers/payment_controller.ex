defmodule WraftDocWeb.Api.V1.PaymentController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Payment, as: PaymentSchema

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Payments"])

  operation(:index,
    summary: "Payment index",
    description: "List all payments done so far",
    operation_id: "payment_index",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"OK", "application/json", PaymentSchema.PaymentIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    %{current_org_id: org_id} = conn.assigns[:current_user]

    with %{
           entries: payments,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.payment_index(org_id, params) do
      render(conn, "index.json",
        payments: payments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a payment",
    description: "Show a payment",
    operation_id: "show_payment",
    parameters: [
      id: [in: :path, type: :string, description: "ID of payment", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", PaymentSchema.ShowPayment},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => p_uuid}) do
    current_user = conn.assigns[:current_user]

    with %Payment{} = payment <- Enterprise.show_payment(p_uuid, current_user) do
      render(conn, "show.json", payment: payment)
    end
  end
end
