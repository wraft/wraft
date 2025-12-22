defmodule WraftDocWeb.Schemas.FormEntry do
  @moduledoc """
  OpenAPI schemas for Form Entry operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule FormFieldEntry do
    @moduledoc """
    Schema for a single form field entry
    """
    OpenApiSpex.schema(%{
      title: "Form Field Entry",
      description: "A single form field entry",
      type: :object,
      properties: %{
        field_id: %Schema{type: :string, format: :uuid, description: "Field ID"},
        value: %Schema{type: :string, description: "Value"}
      },
      required: [:field_id, :value],
      example: %{
        field_id: "0b214501-05be-4d58-a407-51fc763428cd",
        value: "value"
      }
    })
  end

  defmodule FormEntryRequest do
    @moduledoc """
    Schema for creating a form entry
    """
    OpenApiSpex.schema(%{
      title: "Form Entry Request",
      description: "Request to create a form entry",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          description: "List of form field entries",
          items: FormFieldEntry
        },
        pipeline_id: %Schema{
          type: :string,
          format: :uuid,
          description: "Pipeline ID (optional)"
        }
      },
      required: [:data],
      example: %{
        pipeline_id: "aa18afe1-3383-4653-bc0e-505ec3bbfc19",
        data: [
          %{
            field_id: "0b214501-05be-4d58-a407-51fc763428cd",
            value: "sample@gmail.com"
          },
          %{
            field_id: "0b214501-05be-4d58-a407-51fc763428cd",
            value: "value"
          }
        ]
      }
    })
  end

  defmodule FormEntryResponse do
    @moduledoc """
    Schema for form entry response
    """
    OpenApiSpex.schema(%{
      title: "Form Entry Response",
      description: "Response for form entry",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Form Entry ID"},
        form_id: %Schema{type: :string, format: :uuid, description: "Form ID"},
        user_id: %Schema{type: :string, format: :uuid, description: "User ID"},
        trigger_id: %Schema{type: :string, format: :uuid, description: "Trigger ID"},
        pipeline_id: %Schema{type: :string, format: :uuid, description: "Pipeline ID"},
        status: %Schema{
          type: :string,
          enum: ["draft", "submitted", "processing", "completed"],
          description: "Status of the form entry"
        },
        data: %Schema{
          type: :object,
          description: "Form field data as key-value pairs"
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the form entry inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the form entry last updated"
        }
      },
      example: %{
        id: "f507ca98-9848-49af-89f8-a21f12202ec0",
        form_id: "aa18afe1-3383-4653-bc0e-505ec3bbfc19",
        user_id: "af2cf1c6-f342-4042-8425-6346e9fd6c44",
        trigger_id: "af2cf1c6-f342-4042-8425-6346e9fd6c44",
        pipeline_id: "12345678-9abc-def0-1234-56789abcdef0",
        status: "draft",
        data: %{
          "3a266577-c717-4fba-b465-ec7b89301445" => "sample@gmail.com",
          "4adcab31-fabd-4243-9eee-3a755407f8d3" => "value"
        },
        inserted_at: "2024-04-17T07:10:17Z",
        updated_at: "2024-04-17T07:10:17Z"
      }
    })
  end

  defmodule FormEntryIndex do
    @moduledoc """
    Schema for paginated form entry list
    """
    OpenApiSpex.schema(%{
      title: "Form Entry Index Response",
      description: "Paginated list of form entries",
      type: :object,
      properties: %{
        entries: %Schema{
          type: :array,
          description: "List of form entries",
          items: FormEntryResponse
        },
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of entries"}
      },
      example: %{
        entries: [
          %{
            id: "f507ca98-9848-49af-89f8-a21f12202ec0",
            form_id: "aa18afe1-3383-4653-bc0e-505ec3bbfc19",
            user_id: "af2cf1c6-f342-4042-8425-6346e9fd6c44",
            status: "draft",
            data: %{
              "3a266577-c717-4fba-b465-ec7b89301445" => "sample@gmail.com"
            },
            inserted_at: "2024-04-17T07:10:17Z",
            updated_at: "2024-04-17T07:10:17Z"
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
