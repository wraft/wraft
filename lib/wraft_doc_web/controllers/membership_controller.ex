defmodule WraftDocWeb.Api.V1.MembershipController do
  use WraftDocWeb, :controller
  plug(WraftDocWeb.Plug.AddActionLog)
  import Ecto.Query, warn: false

  alias WraftDoc.{
    Enterprise,
    Enterprise.Membership,
    Enterprise.Membership.Payment,
    Enterprise.Plan
  }

  action_fallback(WraftDocWeb.FallbackController)
  use PhoenixSwagger

  def swagger_definitions do
    %{
      MembershipRequest:
        swagger_schema do
          title("Membership request")
          description("Membership update request")

          properties do
            plan_id(:string, "ID of the selected plan")
            razorpay_id(:string, "Razorpay unique ID", required: true)
          end

          example(%{
            plan_id: "kjbdi1237691823i",
            razorpay_id: "pay-23vgoin453412"
          })
        end,
      Membership:
        swagger_schema do
          title("Membership")
          description("A Membership object")

          properties do
            id(:string, "ID of the membership")
            start_end(:string, "Start date of membership")
            end_date(:string, "End date of membership")
            plan_duration(:integer, "Duration of the membership")
            plan(Schema.ref(:Plan))
            inserted_at(:string, "When was the membership created", format: "ISO-8601")
            updated_at(:string, "When was the membership last updated", format: "ISO-8601")
          end

          example(%{
            id: "uhja8324jdadsmsd",
            start_date: "2020-01-21T14:00:00Z",
            end_date: "2020-01-21T14:00:00Z",
            plan_duration: 30,
            plan: %{
              id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
              name: "Basic",
              description: "A basic plan",
              yearly_amount: 10,
              monthly_amount: 6,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      OnlyMembership:
        swagger_schema do
          title("A Membership")
          description("A Membership without plan details")

          properties do
            id(:string, "ID of the membership")
            start_end(:string, "Start date of membership")
            end_date(:string, "End date of membership")
            plan_duration(:integer, "Duration of the membership")
            inserted_at(:string, "When was the membership created", format: "ISO-8601")
            updated_at(:string, "When was the membership last updated", format: "ISO-8601")
          end

          example(%{
            id: "uhja8324jdadsmsd",
            start_date: "2020-01-21T14:00:00Z",
            end_date: "2020-01-21T14:00:00Z",
            plan_duration: 30,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end
    }
  end

  swagger_path :show do
    get("/organisations/{id}/memberships")
    summary("Show membership")
    description("Show membership of an organisation")
    operation_id("show_membership")

    parameters do
      id(:path, :string, "Organisation ID", required: true)
    end

    response(200, "OK", Schema.ref(:Membership))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => o_uuid}) do
    current_user = conn.assigns[:current_user]

    with true <- o_uuid == current_user.organisation.uuid,
         %Membership{} = membership <- Enterprise.get_organisation_membership(o_uuid) do
      render(conn, "membership.json", membership: membership)
    else
      _ ->
        nil
    end
  end

  swagger_path :update do
    put("/memberships/{id}")
    summary("Update a membership")
    description("Update a membership")
    operation_id("update_membership")

    parameters do
      id(:path, :string, "Membership ID", required: true)

      membership(:body, Schema.ref(:MembershipRequest), "Membership to be updated", required: true)
    end

    response(200, "OK", Schema.ref(:Membership))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => m_uuid, "plan_id" => p_uuid, "razorpay_id" => r_id}) do
    current_user = conn.assigns[:current_user]

    with %Membership{} = membership <- Enterprise.get_membership(m_uuid, current_user),
         %Plan{} = plan <- Enterprise.get_plan(p_uuid),
         {:ok, %Razorpay.Payment{} = razorpay} <- Enterprise.get_razorpay_data(r_id),
         %Membership{} = membership <-
           Enterprise.update_membership(current_user, membership, plan, razorpay) do
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

  def update(_conn, _), do: nil
end
