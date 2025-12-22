defmodule WraftDocWeb.Api.V1.MembershipController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug(WraftDocWeb.Plug.AddActionLog)

  import Ecto.Query, warn: false

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Membership
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Enterprise.Plan
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Membership, as: MembershipSchema

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Memberships"])

  operation(:show,
    summary: "Show membership",
    description: "Show membership of an organisation",
    operation_id: "show_membership",
    parameters: [
      id: [in: :path, type: :string, description: "Organisation ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", MembershipSchema.Membership},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => organisation_id}) do
    current_user = conn.assigns[:current_user]

    with true <- organisation_id == current_user.current_org_id,
         %Membership{} = membership <- Enterprise.get_organisation_membership(organisation_id) do
      render(conn, "membership.json", membership: membership)
    else
      _ ->
        {:error, :invalid_id, "Organisation"}
    end
  end

  operation(:update,
    summary: "Update a membership",
    description: "Update a membership",
    operation_id: "update_membership",
    parameters: [
      id: [in: :path, type: :string, description: "Membership ID", required: true]
    ],
    request_body:
      {"Membership to be updated", "application/json", MembershipSchema.MembershipRequest},
    responses: [
      ok: {"OK", "application/json", MembershipSchema.Membership},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => m_id} = params) do
    current_user = conn.assigns[:current_user]

    with %Membership{} = membership <- Enterprise.get_membership(m_id, current_user),
         %Plan{} = plan <- Enterprise.get_plan(params["plan_id"]),
         {:ok, payment_details} <-
           Enterprise.get_razorpay_data(params["razorpay_id"]),
         %Membership{} = membership <-
           Enterprise.update_membership(current_user, membership, plan, payment_details) do
      render(conn, "membership.json", membership: membership)
    else
      {:ok, %Payment{}} ->
        conn
        |> put_status(400)
        |> render("info.json", message: "Payment failed. Membership not updated.!")

      error ->
        error
    end
  end
end
