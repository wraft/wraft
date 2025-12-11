defmodule WraftDocWeb.Schemas.StorageSyncJob do
  @moduledoc """
  OpenAPI schemas for Storage Sync Job operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule SyncJobRequest do
    @moduledoc """
    Schema for sync job request
    """
    OpenApiSpex.schema(%{
      title: "Sync Job Request",
      description: "Request to create or update a storage sync job",
      type: :object,
      properties: %{
        sync_job: %Schema{
          type: :object,
          description: "Sync job details",
          properties: %{
            job_type: %Schema{type: :string, description: "Type of sync job"},
            sync_source: %Schema{type: :string, description: "Source of the sync"},
            status: %Schema{type: :string, description: "Status of the sync job"},
            started_at: %Schema{
              type: :string,
              format: :"date-time",
              description: "When the sync job started"
            },
            completed_at: %Schema{
              type: :string,
              format: :"date-time",
              description: "When the sync job completed"
            },
            items_processed: %Schema{type: :integer, description: "Number of items processed"},
            items_failed: %Schema{type: :integer, description: "Number of items that failed"},
            error_details: %Schema{type: :object, description: "Details of any errors"}
          },
          required: [
            :job_type,
            :sync_source,
            :status,
            :started_at,
            :completed_at,
            :items_processed,
            :items_failed
          ]
        }
      },
      required: [:sync_job],
      example: %{
        sync_job: %{
          job_type: "full_sync",
          sync_source: "google_drive",
          status: "completed",
          started_at: "2025-06-07T21:00:00Z",
          completed_at: "2025-06-07T21:30:00Z",
          items_processed: 100,
          items_failed: 2,
          error_details: %{"errors" => ["File not found", "Permission denied"]}
        }
      }
    })
  end

  defmodule SyncJobResponse do
    @moduledoc """
    Schema for sync job response
    """
    OpenApiSpex.schema(%{
      title: "Sync Job",
      description: "A storage synchronization job",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Sync job ID"},
        job_type: %Schema{type: :string, description: "Type of sync job"},
        sync_source: %Schema{type: :string, description: "Source of the sync"},
        status: %Schema{type: :string, description: "Status of the sync job"},
        started_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the sync job started"
        },
        completed_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When the sync job completed"
        },
        items_processed: %Schema{type: :integer, description: "Number of items processed"},
        items_failed: %Schema{type: :integer, description: "Number of items that failed"},
        error_details: %Schema{type: :object, description: "Details of any errors"},
        repository_id: %Schema{type: :string, format: :uuid, description: "Repository ID"},
        triggered_by_id: %Schema{
          type: :string,
          format: :uuid,
          description: "User who triggered the job"
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the sync job created"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the sync job last updated"
        }
      },
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        job_type: "full_sync",
        sync_source: "google_drive",
        status: "completed",
        started_at: "2025-06-07T21:00:00Z",
        completed_at: "2025-06-07T21:30:00Z",
        items_processed: 100,
        items_failed: 2,
        error_details: %{"errors" => ["File not found", "Permission denied"]},
        repository_id: "550e8400-e29b-41d4-a716-446655440001",
        triggered_by_id: "550e8400-e29b-41d4-a716-446655440002",
        inserted_at: "2025-06-07T21:00:00Z",
        updated_at: "2025-06-07T21:30:00Z"
      }
    })
  end

  defmodule SyncJobsList do
    @moduledoc """
    Schema for list of sync jobs
    """
    OpenApiSpex.schema(%{
      title: "Sync Jobs List",
      description: "List of storage sync jobs",
      type: :array,
      items: SyncJobResponse,
      example: [
        %{
          id: "550e8400-e29b-41d4-a716-446655440000",
          job_type: "full_sync",
          sync_source: "google_drive",
          status: "completed",
          started_at: "2025-06-07T21:00:00Z",
          completed_at: "2025-06-07T21:30:00Z",
          items_processed: 100,
          items_failed: 2,
          error_details: %{},
          repository_id: "550e8400-e29b-41d4-a716-446655440001",
          triggered_by_id: "550e8400-e29b-41d4-a716-446655440002",
          inserted_at: "2025-06-07T21:00:00Z",
          updated_at: "2025-06-07T21:30:00Z"
        }
      ]
    })
  end
end
