defmodule WraftDocWeb.Api.V1.StorageAssetController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  require Logger

  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItems

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
          description("Response containing created storage asset and item")

          properties do
            data(:object, "Created storage item with assets",
              properties: %{
                id: %Schema{type: :string, format: "uuid"},
                name: %Schema{type: :string},
                display_name: %Schema{type: :string},
                item_type: %Schema{type: :string},
                path: %Schema{type: :string},
                mime_type: %Schema{type: :string},
                size: %Schema{type: :integer},
                assets: %Schema{
                  type: :array,
                  items: Schema.ref(:StorageAsset)
                }
              }
            )
          end

          example(%{
            data: %{
              id: "550e8400-e29b-41d4-a716-446655440002",
              name: "contract.pdf",
              display_name: "Contract Agreement",
              item_type: "file",
              path: "/Contracts/Q4",
              mime_type: "application/pdf",
              size: 1024,
              assets: [
                %{
                  id: "650e8400-e29b-41d4-a716-446655440000",
                  filename: "contract.pdf",
                  storage_key: "uploads/contract.pdf",
                  file_size: 1024,
                  mime_type: "application/pdf"
                }
              ]
            }
          })
        end
    }
  end

  @doc """
  Lists storage assets with optional filtering by organisation.
  """
  swagger_path :index do
    get("/api/v1/storage/assets")
    summary("List storage assets")
    description("Returns a list of storage assets for the current organization")
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

  def index(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    # Parse pagination parameters
    _limit = parse_integer(params["limit"], 100, 1, 1000)
    _offset = parse_integer(params["offset"], 0, 0, nil)

    storage_assets = StorageAssets.list_storage_assets_by_organisation(organisation_id)

    Logger.info("Storage assets listed", %{
      organisation_id: organisation_id,
      count: length(storage_assets)
    })

    render(conn, :index, storage_assets: storage_assets)
  end

  swagger_path :upload do
    post("/api/v1/storage/assets/upload")
    summary("Upload a file")

    description("""
    Uploads a new file and creates associated storage asset and item records.
    Performs a complete upload workflow including validation and processing.
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

  @doc """
  Creates a storage asset with file upload.
  Performs a complete upload workflow including storage item creation.

  ## Parameters
  - file: The uploaded file (required)
  - parent_id: Parent folder ID (optional, defaults to root)
  - repository_id: Repository ID (optional)
  - display_name: Custom display name (optional, defaults to filename)
  - classification_level: Security classification (optional, defaults to "public")

  ## Returns
  - 201: Success with created storage asset and item
  - 400: Bad request (invalid parameters)
  - 413: File too large
  - 422: Validation errors
  """
  def upload(conn, %{"file" => file} = params) when not is_nil(file) do
    current_user = conn.assigns[:current_user]

    Logger.info("📁 Starting file upload", %{
      filename: file.filename,
      content_type: file.content_type,
      user_id: current_user.id,
      organisation_id: current_user.current_org_id
    })

    # Validate request parameters
    with :ok <- validate_upload_params(params),
         {:ok, validated_params} <- prepare_validated_params(params, current_user) do
      # Perform the upload
      case StorageItems.create_storage_asset_with_item(current_user, validated_params) do
        {:ok, %{storage_asset: storage_asset, storage_item: storage_item}} ->
          Logger.info("✅ File upload successful", %{
            storage_asset_id: storage_asset.id,
            storage_item_id: storage_item.id,
            filename: storage_item.name
          })

          conn
          |> put_status(:created)
          |> put_resp_header("location", "/api/v1/storage/assets/#{storage_asset.id}")
          |> json(%{data: WraftDocWeb.Api.V1.StorageItemView.data(storage_item, [storage_asset])})

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error("❌ File upload failed - validation error", %{
            errors: changeset.errors,
            filename: file.filename
          })

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            error: "Validation failed",
            details: format_changeset_errors(changeset)
          })
      end
    else
      {:error, :file_too_large} ->
        conn
        |> put_status(:payload_too_large)
        |> json(%{error: "File size exceeds maximum allowed limit"})

      {:error, :invalid_file_type} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "File type not supported"})

      {:error, :invalid_parent_folder} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid parent folder specified"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "File upload is required"})
  end

  swagger_path :create do
    post("/api/v1/storage/assets")
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
    get("/api/v1/storage/assets/{id}")
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
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid(id),
         %StorageAsset{} = storage_asset <-
           StorageAssets.get_storage_asset_by_org(id, organisation_id) do
      render(conn, :show, storage_asset: storage_asset)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage asset not found"})

      {:error, :invalid_uuid} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid asset ID format"})
    end
  end

  swagger_path :update do
    patch("/api/v1/storage/assets/{id}")
    put("/api/v1/storage/assets/{id}")
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
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid(id),
         %StorageAsset{} = storage_asset <-
           StorageAssets.get_storage_asset_by_org(id, organisation_id),
         {:ok, %StorageAsset{} = updated_asset} <-
           StorageAssets.update_storage_asset(storage_asset, storage_asset_params) do
      render(conn, :show, storage_asset: updated_asset)
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage asset not found"})

      {:error, :invalid_uuid} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid asset ID format"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Validation failed",
          details: format_changeset_errors(changeset)
        })
    end
  end

  # Delete action
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/v1/storage/assets/{id}")
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
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid(id),
         %StorageAsset{} = storage_asset <-
           StorageAssets.get_storage_asset_by_org(id, organisation_id),
         {:ok, %StorageAsset{}} <- StorageAssets.delete_storage_asset(storage_asset) do
      send_resp(conn, :no_content, "")
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage asset not found"})

      {:error, :invalid_uuid} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid asset ID format"})
    end
  end

  # Private helper functions

  # Validates upload parameters
  defp validate_upload_params(%{"file" => %Plug.Upload{} = file} = params) do
    with :ok <- validate_file_size(file),
         :ok <- validate_file_type(file) do
      validate_parent_folder(params)
    end
  end

  defp validate_upload_params(_params), do: {:error, "File upload is required"}

  # Validates file size
  defp validate_file_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      # 10MB limit
      {:ok, %{size: size}} when size <= 10 * 1024 * 1024 -> :ok
      {:ok, %{size: _}} -> {:error, :file_too_large}
      {:error, _} -> {:error, "Could not read file"}
    end
  end

  # Validates file type
  defp validate_file_type(%Plug.Upload{filename: filename}) do
    extension = String.downcase(Path.extname(filename))

    allowed_extensions =
      ~w(.jpg .jpeg .png .pdf .doc .docx .xls .xlsx .ppt .pptx .txt .odt .zip .csv)

    if extension in allowed_extensions do
      :ok
    else
      {:error, :invalid_file_type}
    end
  end

  # Validates parent folder exists and is accessible
  defp validate_parent_folder(%{"parent_id" => parent_id})
       when is_binary(parent_id) and parent_id != "" do
    # This should validate that the parent folder exists and is accessible
    # For now, we'll just validate UUID format
    case Ecto.UUID.cast(parent_id) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_parent_folder}
    end
  end

  defp validate_parent_folder(_params), do: :ok

  # Prepares validated parameters for upload
  defp prepare_validated_params(params, current_user) do
    validated_params =
      params
      |> Map.put("creator_id", current_user.id)
      |> Map.put("organisation_id", current_user.current_org_id)

    {:ok, validated_params}
  end

  # Helper function to parse integer parameters
  defp parse_integer(value, default, min, max) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= min ->
        if max && int > max, do: max, else: int

      _ ->
        default
    end
  end

  defp parse_integer(_, default, _, _), do: default

  # Helper function to validate UUID format
  defp validate_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_uuid}
    end
  end

  # Formats changeset errors for API response
  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", inspect(value))
      end)
    end)
  end
end
