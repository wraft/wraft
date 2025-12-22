defmodule WraftDocWeb.Schemas.InstanceApproval do
  @moduledoc """
  OpenAPI schemas for Instance Approval operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ApprovalHistoryItem do
    @moduledoc """
    Schema for a single approval history item
    """
    OpenApiSpex.schema(%{
      title: "Approval History Item",
      description: "A single approval history entry",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Approval history ID"},
        review_status: %Schema{
          type: :string,
          enum: ["approved", "rejected", "pending"],
          description: "Review status"
        },
        reviewed_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the review was completed"
        },
        approver: %Schema{
          type: :object,
          description: "Approver information",
          properties: %{
            id: %Schema{type: :string, format: :uuid, description: "Approver ID"},
            name: %Schema{type: :string, description: "Approver name"},
            profile_pic: %Schema{type: :string, description: "Approver profile picture URL"}
          }
        },
        to_state: %Schema{
          type: :object,
          description: "Target state information",
          properties: %{
            id: %Schema{type: :string, format: :uuid, description: "State ID"},
            state: %Schema{type: :string, description: "State name"},
            order: %Schema{type: :integer, description: "State order"}
          }
        }
      },
      example: %{
        id: "016a9ade-6ffb-4ef2-b32e-af1c71bf7803",
        review_status: "approved",
        reviewed_at: "2024-03-22T13:11:48Z",
        approver: %{
          id: "550e8400-e29b-41d4-a716-446655440000",
          name: "John",
          profile_pic: "logo.png"
        },
        to_state: %{
          id: "c10ae004-69b9-47ee-ba9e-40217e42334f",
          state: "Review",
          order: 8
        }
      }
    })
  end

  defmodule ApprovalHistoryIndex do
    @moduledoc """
    Schema for approval history list
    """
    OpenApiSpex.schema(%{
      title: "Approval History Index",
      description: "List of approval history entries",
      type: :array,
      items: ApprovalHistoryItem,
      example: [
        %{
          id: "016a9ade-6ffb-4ef2-b32e-af1c71bf7803",
          review_status: "approved",
          reviewed_at: "2024-03-22T13:11:48Z",
          approver: %{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "John",
            profile_pic: "logo.png"
          },
          to_state: %{
            id: "c10ae004-69b9-47ee-ba9e-40217e42334f",
            state: "Review",
            order: 8
          }
        }
      ]
    })
  end
end
