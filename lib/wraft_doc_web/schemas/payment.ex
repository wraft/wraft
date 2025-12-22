defmodule WraftDocWeb.Schemas.Payment do
  @moduledoc """
  Schema for Payment request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Payment do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Payment",
      description: "A payment",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Payment id"},
        razorpay_id: %Schema{type: :string, description: "Razorpay ID"},
        start_date: %Schema{type: :string, description: "Start date of the plan"},
        end_date: %Schema{type: :string, description: "End date of the plan"},
        invoice_number: %Schema{type: :string, description: "Invoice number"},
        invoice: %Schema{type: :string, description: "Invoice PDF file line"},
        amount: %Schema{type: :number, format: :float, description: "Amount paid"},
        action: %Schema{type: :string, description: "The action of payment"},
        status: %Schema{type: :string, description: "Payment status"},
        organisation: %Schema{anyOf: [WraftDocWeb.Schemas.Organisation.Organisation]},
        creator: %Schema{anyOf: [WraftDocWeb.Schemas.User.User]},
        meta: %Schema{type: :object, description: "Razorpay data"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the payment made",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the plan last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
        razorpay_id: "pay-kmn47ysda",
        start_date: "2020-01-21T14:00:00Z",
        end_date: "2020-01-21T14:00:00Z",
        invoice_number: "WRAFTDOC-Invoice-001",
        invoice:
          "organisations/f5837766-573f-427f-a916-cf39a3518c7b/invoice/WRAFTDOC-Invoice-001.pdf",
        amount: 1000.0,
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
    })
  end

  defmodule Payments do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All payments of an organisation",
      description: "All plans that have been done by an organisation",
      type: :array,
      items: Payment
    })
  end

  defmodule PaymentIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Payment index",
      description: "Payment index with pagination",
      type: :object,
      properties: %{
        payments: Payments,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        payments: [
          %{
            id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
            razorpay_id: "pay-kmn47ysda",
            start_date: "2020-01-21T14:00:00Z",
            end_date: "2020-01-21T14:00:00Z",
            invoice_number: "WRAFTDOC-Invoice-001",
            invoice:
              "organisations/f5837766-573f-427f-a916-cf39a3518c7b/invoice/WRAFTDOC-Invoice-001.pdf",
            amount: 1000.0,
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
      }
    })
  end

  defmodule ShowPayment do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show a Payment",
      description: "Show a payment",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Payment id"},
        razorpay_id: %Schema{type: :string, description: "Razorpay ID"},
        start_date: %Schema{type: :string, description: "Start date of the plan"},
        end_date: %Schema{type: :string, description: "End date of the plan"},
        invoice_number: %Schema{type: :string, description: "Invoice number"},
        invoice: %Schema{type: :string, description: "Invoice PDF file line"},
        amount: %Schema{type: :number, format: :float, description: "Amount paid"},
        action: %Schema{type: :string, description: "The action of payment"},
        status: %Schema{type: :string, description: "Payment status"},
        organisation: %Schema{anyOf: [WraftDocWeb.Schemas.Organisation.Organisation]},
        membership: %Schema{anyOf: [WraftDocWeb.Schemas.Membership.OnlyMembership]},
        creator: %Schema{anyOf: [WraftDocWeb.Schemas.User.User]},
        from_plan: %Schema{anyOf: [WraftDocWeb.Schemas.Plan.Plan]},
        to_plan: %Schema{anyOf: [WraftDocWeb.Schemas.Plan.Plan]},
        meta: %Schema{type: :object, description: "Razorpay data"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the payment made",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the plan last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
        razorpay_id: "pay-kmn47ysda",
        start_date: "2020-01-21T14:00:00Z",
        end_date: "2020-01-21T14:00:00Z",
        invoice_number: "WRAFTDOC-Invoice-001",
        invoice:
          "organisations/f5837766-573f-427f-a916-cf39a3518c7b/invoice/WRAFTDOC-Invoice-001.pdf",
        amount: 1000.0,
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
      }
    })
  end
end
