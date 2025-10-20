defmodule WraftDocWeb.Api.V1.StorageAssetController do
  @moduledoc """
  API endpoints for managing storage assets (file uploads and metadata).
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  require Logger

  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItems

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      StorageAsset:
        swagger_schema do
          title("Storage Asset")
          description("A physical storage asset representing an uploaded file.")

          properties do
            id(:string, "The ID of the storage asset", required: true, format: "uuid")
            filename(:string, "Original filename", required: true)
            storage_key(:string, "Storage system key", required: true)
            storage_backend(:string, "Storage backend identifier")
            file_size(:integer, "File size in bytes")
            mime_type(:string, "MIME type of the file")

            processing_status(:string, "Processing status",
              enum: ["pending", "processing", "completed", "failed"]
            )

            upload_completed_at(:string, "Upload completion timestamp", format: "ISO-8601")
            checksum_sha256(:string, "File checksum")
            thumbnail_path(:string, "Path to generated thumbnail")
            preview_path(:string, "Path to generated preview")
            inserted_at(:string, "Creation timestamp", format: "ISO-8601")
            updated_at(:string, "Last update timestamp", format: "ISO-8601")
            url(:string, "Access URL for the asset")
          end

          example(%{
            id: "650e8400-e29b-41d4-a716-446655440000",
            filename: "contract.pdf",
            storage_key: "uploads/contract.pdf",
            storage_backend: "s3",
            file_size: 1024,
            mime_type: "application/pdf",
            processing_status: "completed",
            upload_completed_at: "2023-01-15T10:30:00Z",
            checksum_sha256: "a1b2c3...",
            thumbnail_path: "thumbnails/contract.jpg",
            preview_path: "previews/contract.html",
            inserted_at: "2023-01-15T10:25:00Z",
            updated_at: "2023-01-15T10:30:00Z",
            url: "https://storage.example.com/uploads/contract.pdf"
          })
        end,
      StorageAssetList:
        swagger_schema do
          title("Storage Asset List")
          description("A list of storage assets")
          type(:array)
          items(Schema.ref(:StorageAsset))
        end,
      StorageAssetCreateParams:
        swagger_schema do
          title("Storage Asset Creation Parameters")
          description("Parameters for creating a storage asset (legacy endpoint)")

          properties do
            filename(:string, "Original filename", required: true)
            storage_key(:string, "Storage system key", required: true)
            file_size(:integer, "File size in bytes")
            mime_type(:string, "MIME type of the file")
          end

          example(%{
            filename: "contract.pdf",
            storage_key: "uploads/contract.pdf",
            file_size: 1024,
            mime_type: "application/pdf"
          })
        end,
      FileUploadParams:
        swagger_schema do
          title("File Upload Parameters")
          description("Parameters for uploading a new file")

          properties do
            file(:string, "The file to upload", required: true, format: "binary")
            parent_id(:string, "Parent folder ID", format: "uuid")
            repository_id(:string, "Repository ID", format: "uuid")
            display_name(:string, "Custom display name")

            classification_level(:string, "Security classification level",
              enum: ["public", "internal", "confidential", "secret"]
            )
          end

          example(%{
            parent_id: "550e8400-e29b-41d4-a716-446655440000",
            repository_id: "550e8400-e29b-41d4-a716-446655440001",
            display_name: "Contract Agreement",
            classification_level: "confidential"
          })
        end,
      FileUploadResponse:
        swagger_schema do
          title("File Upload Response")
          description("Successful file upload response")

          properties do
            data(:object, "Created storage item with assets",
              properties: %{
                id: %{
                  type: :string,
                  format: "uuid",
                  example: "550e8400-e29b-41d4-a716-446655440000"
                },
                name: %{type: :string, example: "contract.pdf"},
                display_name: %{type: :string, example: "Contract Agreement"},
                item_type: %{type: :string, example: "file"},
                path: %{type: :string, example: "/Contracts/Q3"},
                mime_type: %{type: :string, example: "application/pdf"},
                size: %{type: :integer, example: 1024},
                assets: %{
                  type: :array,
                  items: Schema.ref(:StorageAsset),
                  example: [
                    %{
                      id: "650e8400-e29b-41d4-a716-446655440000",
                      filename: "contract.pdf",
                      storage_key: "uploads/2023/contract.pdf",
                      file_size: 1024,
                      mime_type: "application/pdf"
                    }
                  ]
                }
              }
            )
          end

          example(%{
            "data" => %{
              "id" => "550e8400-e29b-41d4-a716-446655440000",
              "name" => "contract.pdf",
              "display_name" => "Contract Agreement",
              "item_type" => "file",
              "path" => "/Contracts/Q3",
              "mime_type" => "application/pdf",
              "size" => 1024,
              "assets" => [
                %{
                  "id" => "650e8400-e29b-41d4-a716-446655440000",
                  "filename" => "contract.pdf",
                  "storage_key" => "uploads/2023/contract.pdf",
                  "file_size" => 1024,
                  "mime_type" => "application/pdf"
                }
              ]
            }
          })
        end,
      ErrorResponse:
        swagger_schema do
          title("Error Response")
          description("Standard error format")

          properties do
            error(:string, "Error message", example: "File upload failed")
            details(:string, "Additional details", example: "File size exceeds 10MB limit")
            validation_errors(:object, "Field-specific errors", required: false)
          end

          example(%{
            "error" => "Validation failed",
            "details" => "Invalid file type",
            "validation_errors" => %{
              "file" => "Must be a PDF, DOCX, or JPG file"
            }
          })
        end
    }
  end

  swagger_path :index do
    get("/storage/assets")
    summary("List storage assets")

    description("""
    Returns paginated list of storage assets for the current organization.

    ### Filtering
    - By repository: `?repository_id=UUID`
    - By parent folder: `?parent_id=UUID`
    - By MIME type: `?mime_type=type/subtype`

    ### Sorting
    Supported via `sort_by` and `sort_order` parameters
    """)

    operation_id("listStorageAssets")
    produces("application/json")

    parameters do
      # Add query parameters here
      limit(:query, :integer, "Number of items to return",
        default: 100,
        minimum: 1,
        maximum: 1000
      )

      offset(:query, :integer, "Number of items to skip", default: 0, minimum: 0)
      # repository_id(:query, :string, "Filter by repository ID", format: "uuid")
      # parent_id(:query, :string, "Filter by parent folder ID", format: "uuid")
      # mime_type(:query, :string, "Filter by MIME type")
    end

    response(200, "OK", Schema.ref(:StorageAssetList))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @doc """
  Lists storage assets with optional filtering.

  ## Route
  GET /api/v1/storage/assets

  ## Parameters
  - limit: Pagination limit (default: 100)
  - offset: Pagination offset (default: 0)
  - repository_id: Filter by repository
  - parent_id: Filter by parent folder
  - mime_type: Filter by MIME type

  ## Examples
      # Basic listing
      GET /api/v1/storage/assets

      # Filtered listing
      GET /api/v1/storage/assets?parent_id=550e8400-e29b-41d4-a716-446655440000&limit=50
  """
  def index(conn, _params) do
    current_user = conn.assigns[:current_user]

    with storage_assets <-
           StorageAssets.list_storage_assets_by_organisation(current_user.current_org_id) do
      render(conn, :index, storage_assets: storage_assets)
    end
  end

  swagger_path :upload do
    post("/storage/assets/upload")
    summary("Upload a file")

    description("""
    Main endpoint for file uploads. Creates both:
    1. StorageAsset (physical file metadata)
    2. StorageItem (logical file representation)

    ### Supported Files
    - Documents: PDF, DOCX, XLSX, PPTX, TXT
    - Images: JPG, PNG
    - Archives: ZIP
    - Max size: 10MB
    """)

    operation_id("uploadFile")
    consumes("multipart/form-data")
    produces("application/json")

    parameters do
      file(:formData, :file, "The file to upload", required: true)
      parent_id(:formData, :string, "Parent folder ID", format: "uuid")
      repository_id(:formData, :string, "Repository ID", format: "uuid")
      display_name(:formData, :string, "Custom display name")

      classification_level(:formData, :string, "Security classification level",
        enum: ["public", "internal", "confidential", "secret"]
      )
    end

    response(201, "Created", Schema.ref(:FileUploadResponse))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(413, "Payload Too Large", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def upload(conn, %{"file" => _file} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, storage_item} <-
           StorageItems.create_storage_asset_with_item(current_user, params) do
      conn
      |> put_status(:created)
      |> render(:show_upload, storage_item: storage_item)
    end
  end

  def upload(_conn, _params), do: {:error, :file_required}

  swagger_path :create do
    post("/storage/assets")
    summary("Create a storage asset (legacy)")

    description("""
    Legacy endpoint for creating storage assets directly.
    Prefer the upload endpoint for new implementations.
    """)

    operation_id("createStorageAsset")
    consumes("application/json")
    produces("application/json")

    parameters do
      asset(:body, Schema.ref(:StorageAssetCreateParams), "Storage asset creation parameters",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StorageAsset))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @doc """
  Creates a storage asset (legacy endpoint for backwards compatibility).
  """
  def create(conn, %{"asset" => storage_asset_params}) do
    with {:ok, %StorageAsset{} = storage_asset} <-
           StorageAssets.create_storage_asset(storage_asset_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_assets/#{storage_asset}")
      |> render(:show, storage_asset: storage_asset)
    end
  end

  swagger_path :show do
    get("/storage/assets/{id}")
    summary("Get storage asset details")
    description("Returns detailed information about a specific storage asset")
    operation_id("getStorageAsset")
    produces("application/json")

    parameters do
      id(:path, :string, "ID of the storage asset", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:StorageAsset))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
  Shows a storage asset by ID.
  """

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %StorageAsset{} = storage_asset <-
           StorageAssets.get_storage_asset_by_org(id, current_user.current_org_id) do
      render(conn, :show, storage_asset: storage_asset)
    end
  end

  swagger_path :update do
    patch("/storage/assets/{id}")
    put("/storage/assets/{id}")
    summary("Update a storage asset")
    description("Updates metadata for an existing storage asset")
    operation_id("updateStorageAsset")
    consumes("application/json")
    produces("application/json")

    parameters do
      id(:path, :string, "ID of the storage asset", required: true, format: "uuid")

      storage_asset(:body, :object, "Storage asset update parameters",
        example: %{
          processing_status: "completed",
          metadata: %{
            notes: "Processed successfully"
          }
        }
      )
    end

    response(200, "OK", Schema.ref(:StorageAsset))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @doc """
  Updates a storage asset.
  """
  def update(conn, %{"id" => id, "storage_asset" => storage_asset_params}) do
    current_user = conn.assigns[:current_user]

    with %StorageAsset{} = storage_asset <-
           StorageAssets.get_storage_asset_by_org(id, current_user.current_org_id),
         {:ok, %StorageAsset{} = updated_asset} <-
           StorageAssets.update_storage_asset(storage_asset, storage_asset_params) do
      render(conn, :show, storage_asset: updated_asset)
    end
  end

  # Delete action
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/storage/assets/{id}")
    summary("Delete a storage asset")

    description("""
    Soft deletes a storage asset.
    The actual file may be retained in storage according to retention policies.
    """)

    operation_id("deleteStorageAsset")
    produces("application/json")

    parameters do
      id(:path, :string, "ID of the storage asset to delete", required: true, format: "uuid")
    end

    response(204, "No Content")
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
  Soft deletes a storage asset.
  """
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %StorageAsset{} = storage_asset <-
           StorageAssets.get_storage_asset_by_org(id, current_user.current_org_id),
         {:ok, %StorageAsset{}} <- StorageAssets.delete_storage_asset(storage_asset) do
      send_resp(conn, :no_content, "")
    end
  end
end
