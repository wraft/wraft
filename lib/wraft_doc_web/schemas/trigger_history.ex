defmodule WraftDocWeb.Schemas.TriggerHistory do
  @moduledoc """
  Schema for TriggerHistory request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule GeneralResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "General response",
      description: "Response for pipeline trigger and bulk jobs.",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Response message"},
        pipeline_id: %Schema{type: :string, description: "Pipeline ID"},
        trigger_id: %Schema{type: :string, description: "Trigger ID"}
      },
      example: %{
        info: "Trigger accepted.",
        pipeline_id: "1232148nb3478",
        trigger_id: "147832148nb3478"
      }
    })
  end

  defmodule TriggerData do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Data of trigger message",
      description: "Data of a trigger message",
      type: :object,
      properties: %{
        data: %Schema{type: :object, description: "Data of a trigger message"}
      },
      required: [:data],
      example: %{data: %{name: "John Doe", position: "HR Manager"}}
    })
  end

  defmodule Item do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "A trigger history object",
      description: "A trigger history object",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the trigger history"},
        data: %Schema{type: :object, description: "Input data of the the trigger history"},
        response: %Schema{type: :object, description: "Response data of the the trigger history"},
        state: %Schema{type: :string, description: "State of the trigger history"},
        start_time: %Schema{
          type: :string,
          format: "date-time",
          description: "Start time of the trigger history"
        },
        end_time: %Schema{
          type: :string,
          format: "date-time",
          description: "End time of the trigger history"
        },
        duration: %Schema{
          type: :integer,
          description: "Duration of execution of the trigger history"
        },
        zip_file: %Schema{type: :string, description: "Zip file of the trigger history"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Trigger history created time"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "Trigger history last updated time"
        },
        # Placeholder for User schema
        user: %Schema{type: :object}
      },
      required: [:id, :data, :state, :start_time, :end_time, :duration, :zip_file],
      example: %{
        id: "jhdiuh23y498sjdbda",
        data: %{name: "John Doe"},
        state: "success",
        response: %{
          documents: [%{id: "123", instance_id: "CTR001", title: "Document Title"}],
          documents_count: 1,
          status: "completed",
          state: "executing",
          pipeline_id: "a9cc343b-857e-4e8a-8262-fc7badaebdfs",
          trigger_history_id: "jhdiuh23y498sjdbda",
          input_data: %{
            "0eef6b6b-c201-4e82-9464-d66d1659f822" => "23-03-2025",
            "0eef6b6b-c201-4e82-9464-d66d1659f823" => "John Doe"
          }
        },
        start_time: "2020-01-21 14:00:00",
        end_time: "2020-01-21 14:12:00",
        duration: 720,
        zip_file: "builds-2020-01-21T14:11:58.565745Z.zip",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z",
        creator: %{
          id: "1232148nb3478",
          name: "John Doe",
          email: "email@xyz.com",
          email_verify: true,
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule IndexResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Trigger History Index",
      type: :object,
      properties: %{
        triggers: %Schema{type: :array, items: Item},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        triggers: [
          %{
            id: "jhdiuh23y498sjdbda",
            data: %{name: "John Doe"},
            state: "success",
            start_time: "2020-01-21 14:00:00",
            end_time: "2020-01-21 14:12:00",
            duration: 720,
            zip_file: "builds-2020-01-21T14:11:58.565745Z.zip",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
