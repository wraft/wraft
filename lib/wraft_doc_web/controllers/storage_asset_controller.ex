defmodule WraftDocWeb.Api.V1.StorageAssetController do
  @moduledoc """
  API endpoints for managing storage assets (file uploads and metadata).
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs
  require Logger

  alias WraftDoc.Storages.StorageAsset
  alias WraftDoc.Storages.StorageAssets
  alias WraftDoc.Storages.StorageItems
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.StorageAsset, as: StorageAssetSchema

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Storage Assets"])

  operation(:index,
    summary: "List storage assets",
    description: """
    Returns paginated list of storage assets for the current organization.

    ### Filtering
    - By repository: `?repository_id=UUID`
    - By parent folder: `?parent_id=UUID`
    - By MIME type: `?mime_type=type/subtype`

    ### Sorting
    Supported via `sort_by` and `sort_order` parameters
    """,
    operation_id: "listStorageAssets",
    parameters: [
      limit: [
        in: :query,
        type: :integer,
        description: "Number of items to return (default: 100, min: 1, max: 1000)"
      ],
      offset: [in: :query, type: :integer, description: "Number of items to skip (default: 0)"]
      # repository_id: [in: :query, type: :string, description: "Filter by repository ID", format: "uuid"],
      # parent_id: [in: :query, type: :string, description: "Filter by parent folder ID", format: "uuid"],
      # mime_type: [in: :query, type: :string, description: "Filter by MIME type"]
    ],
    responses: [
      ok: {"OK", "application/json", StorageAssetSchema.StorageAssetList},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:upload,
    summary: "Upload a file",
    description: """
    Main endpoint for file uploads. Creates both:
    1. StorageAsset (physical file metadata)
    2. StorageItem (logical file representation)

    ### Supported Files
    - Documents: PDF, DOCX, XLSX, PPTX, TXT
    - Images: JPG, PNG
    - Archives: ZIP
    - Max size: 10MB
    """,
    operation_id: "uploadFile",
    request_body:
      {"The file to upload", "multipart/form-data", StorageAssetSchema.FileUploadParams},
    responses: [
      created: {"Created", "application/json", StorageAssetSchema.FileUploadResponse},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      request_entity_too_large: {"Payload Too Large", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

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

  operation(:create,
    summary: "Create a storage asset (legacy)",
    description: """
    Legacy endpoint for creating storage assets directly.
    Prefer the upload endpoint for new implementations.
    """,
    operation_id: "createStorageAsset",
    request_body:
      {"Storage asset creation parameters", "application/json",
       StorageAssetSchema.StorageAssetCreateParams},
    responses: [
      created: {"Created", "application/json", StorageAssetSchema.StorageAsset},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @doc """
  Creates a storage asset (legacy endpoint for backwards compatibility).
  """
  def create(conn, %{"asset" => storage_asset_params}) do
    with {:ok, %StorageAsset{} = storage_asset} <-
           StorageAssets.create_storage_asset(storage_asset_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_assets/#{storage_asset.id}")
      |> render(:show, storage_asset: storage_asset)
    end
  end

  operation(:show,
    summary: "Get storage asset details",
    description: "Returns detailed information about a specific storage asset",
    operation_id: "getStorageAsset",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the storage asset (UUID)",
        required: true
      ]
    ],
    responses: [
      ok: {"OK", "application/json", StorageAssetSchema.StorageAsset},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

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

  operation(:update,
    summary: "Update a storage asset",
    description: "Updates metadata for an existing storage asset",
    operation_id: "updateStorageAsset",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the storage asset (UUID)",
        required: true
      ]
    ],
    request_body:
      {"Storage asset update parameters", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           processing_status: %OpenApiSpex.Schema{
             type: :string,
             enum: ["pending", "processing", "completed", "failed"]
           },
           metadata: %OpenApiSpex.Schema{type: :object}
         },
         example: %{
           processing_status: "completed",
           metadata: %{
             notes: "Processed successfully"
           }
         }
       }},
    responses: [
      ok: {"OK", "application/json", StorageAssetSchema.StorageAsset},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

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
  operation(:delete,
    summary: "Delete a storage asset",
    description: """
    Soft deletes a storage asset.
    The actual file may be retained in storage according to retention policies.
    """,
    operation_id: "deleteStorageAsset",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the storage asset to delete (UUID)",
        required: true
      ]
    ],
    responses: [
      no_content: {"No Content", "application/json", nil},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

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
