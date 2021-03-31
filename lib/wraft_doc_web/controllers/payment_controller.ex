defmodule WraftDocWeb.Api.V1.PaymentController do
  use WraftDocWeb, :controller
  plug(WraftDocWeb.Plug.AddActionLog)
  alias WraftDoc.{Enterprise, Enterprise.Membership.Payment}
  action_fallback(WraftDocWeb.FallbackController)
  use PhoenixSwagger

  def swagger_definitions do
    %{
      Payment:
        swagger_schema do
          title("Payment")
          description("A payment")

          properties do
            id(:string, "Payment id")
            razorpay_id(:string, "Razorpay ID")
            start_date(:string, "Start date of the plan")
            end_date(:string, "End date of the plan")
            invoice_number(:string, "Invoice number")
            invoice(:string, "Invoice PDF file line")
            amount(:float, "Amount paid")
            action(:string, "The action of payment")
            status(:string, "Payment status")
            organisation(Schema.ref(:Organisation))
            creator(Schema.ref(:User))
            meta(:map, "Razorpay data")
            inserted_at(:string, "When was the payment made", format: "ISO-8601")
            updated_at(:string, "When was the plan last updated", format: "ISO-8601")
          end

          example(%{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            razorpay_id: "pay-kmn47ysda",
            start_date: "2020-01-21T14:00:00Z",
            end_date: "2020-01-21T14:00:00Z",
            invoice_number: "WRAFTDOC-Invoice-001",
            invoice: "uploads/invoice/WRAFTDOC-Invoice-001.pdf",
            amount: 1000,
            action: "upgrade",
            status: "success",
            organisation: %{
              id: "mnbjhb23488n23e",
              name: "ABC enterprices",
              legal_name: "ABC enterprices LLC",
              address: "#24, XV Building, TS DEB Layout ",
              name_of_ceo: "John Doe",
              name_of_cto: "Foo Doo",
              gstin: "32AA65FF56545353",
              corporate_id: "BNIJSN1234NGT",
              email: "abcent@gmail.com",
              logo: "/logo.jpg",
              phone: "865623232",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      Payments:
        swagger_schema do
          title("All payments of an organisation")
          description("All plans that have been done by an organisation")
          type(:array)
          items(Schema.ref(:Payment))
        end,
      PaymentIndex:
        swagger_schema do
          title("Payment index")
          description("Payment index with pagination")

          properties do
            payments(Schema.ref(:Payments))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            payments: [
              %{
                id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
                razorpay_id: "pay-kmn47ysda",
                start_date: "2020-01-21T14:00:00Z",
                end_date: "2020-01-21T14:00:00Z",
                invoice_number: "WRAFTDOC-Invoice-001",
                invoice: "uploads/invoice/WRAFTDOC-Invoice-001.pdf",
                amount: 1000,
                action: "upgrade",
                status: "success",
                organisation: %{
                  id: "mnbjhb23488n23e",
                  name: "ABC enterprices",
                  legal_name: "ABC enterprices LLC",
                  address: "#24, XV Building, TS DEB Layout ",
                  name_of_ceo: "John Doe",
                  name_of_cto: "Foo Doo",
                  gstin: "32AA65FF56545353",
                  corporate_id: "BNIJSN1234NGT",
                  email: "abcent@gmail.com",
                  logo: "/logo.jpg",
                  phone: "865623232",
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                creator: %{
                  id: "1232148nb3478",
                  name: "John Doe",
                  email: "email@xyz.com",
                  email_verify: true,
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end,
      ShowPayment:
        swagger_schema do
          title("Show a Payment")
          description("Show a payment")

          properties do
            id(:string, "Payment id")
            razorpay_id(:string, "Razorpay ID")
            start_date(:string, "Start date of the plan")
            end_date(:string, "End date of the plan")
            invoice_number(:string, "Invoice number")
            invoice(:string, "Invoice PDF file line")
            amount(:float, "Amount paid")
            action(:string, "The action of payment")
            status(:string, "Payment status")
            organisation(Schema.ref(:Organisation))
            membership(Schema.ref(:OnlyMembership))
            creator(Schema.ref(:User))
            from_plan(Schema.ref(:Plan))
            to_plan(Schema.ref(:Plan))
            meta(:map, "Razorpay data")
            inserted_at(:string, "When was the payment made", format: "ISO-8601")
            updated_at(:string, "When was the plan last updated", format: "ISO-8601")
          end

          example(%{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            razorpay_id: "pay-kmn47ysda",
            start_date: "2020-01-21T14:00:00Z",
            end_date: "2020-01-21T14:00:00Z",
            invoice_number: "WRAFTDOC-Invoice-001",
            invoice: "uploads/invoice/WRAFTDOC-Invoice-001.pdf",
            amount: 1000,
            action: "upgrade",
            status: "success",
            organisation: %{
              id: "mnbjhb23488n23e",
              name: "ABC enterprices",
              legal_name: "ABC enterprices LLC",
              address: "#24, XV Building, TS DEB Layout ",
              name_of_ceo: "John Doe",
              name_of_cto: "Foo Doo",
              gstin: "32AA65FF56545353",
              corporate_id: "BNIJSN1234NGT",
              email: "abcent@gmail.com",
              logo: "/logo.jpg",
              phone: "865623232",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            membership: %{
              id: "uhja8324jdadsmsd",
              start_date: "2020-01-21T14:00:00Z",
              end_date: "2020-01-21T14:00:00Z",
              plan_duration: 30,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            from_plan: %{
              id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
              name: "Basic",
              description: "A basic plan",
              yearly_amount: 10,
              monthly_amount: 6,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            to_plan: %{
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
        end
    }
  end

  swagger_path :index do
    get("/payments")
    summary("Payment index")
    description("List all payments done so far")
    operation_id("payment_index")
    parameter(:page, :query, :string, "Page number")
    response(200, "OK", Schema.ref(:PaymentIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    %{organisation_id: org_id} = conn.assigns[:current_user]

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

  swagger_path :show do
    get("/payments/{id}")
    summary("Show a payment")
    description("Show a payment")
    operation_id("show_payment")

    parameter(:id, :path, :string, "ID of payment", required: true)

    response(200, "OK", Schema.ref(:ShowPayment))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => p_uuid}) do
    current_user = conn.assigns[:current_user]

    with %Payment{} = payment <- Enterprise.show_payment(p_uuid, current_user) do
      render(conn, "show.json", payment: payment)
    end
  end
end
