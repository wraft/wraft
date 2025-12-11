defmodule WraftDocWeb.Schemas.Membership do
  @moduledoc """
  Schema for Membership request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule MembershipRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Membership request",
      description: "Membership update request",
      type: :object,
      properties: %{
        plan_id: %Schema{type: :string, description: "ID of the selected plan"},
        razorpay_id: %Schema{type: :string, description: "Razorpay unique ID"}
      },
      required: [:razorpay_id],
      example: %{
        plan_id: "kjbdi1237691823i",
        razorpay_id: "pay-23vgoin453412"
      }
    })
  end

  defmodule Membership do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Membership",
      description: "A Membership object",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the membership"},
        start_date: %Schema{type: :string, description: "Start date of membership"},
        end_date: %Schema{type: :string, description: "End date of membership"},
        plan_duration: %Schema{type: :integer, description: "Duration of the membership"},
        plan: WraftDocWeb.Schemas.Plan.Plan,
        inserted_at: %Schema{
          type: :string,
          description: "When was the membership created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the membership last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "uhja8324jdadsmsd",
        start_date: "2020-01-21T14:00:00Z",
        end_date: "2020-01-21T14:00:00Z",
        plan_duration: 30,
        plan: %{
          id: "c68b0988-790b-45e8-965c-c4aeb427e70d",
          name: "Basic",
          description: "A basic plan",
          features: ["Feature 1", "Feature 2"],
          plan_id: "123456789",
          plan_amount: "6",
          product_id: "123456789",
          billing_interval: "month",
          limits: %{
            instance_create: 25,
            content_type_create: 25,
            organisation_create: 25,
            organisation_invite: 25
          },
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        },
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule OnlyMembership do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "A Membership",
      description: "A Membership without plan details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the membership"},
        start_date: %Schema{type: :string, description: "Start date of membership"},
        end_date: %Schema{type: :string, description: "End date of membership"},
        plan_duration: %Schema{type: :integer, description: "Duration of the membership"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the membership created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the membership last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "uhja8324jdadsmsd",
        start_date: "2020-01-21T14:00:00Z",
        end_date: "2020-01-21T14:00:00Z",
        plan_duration: 30,
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end
end
