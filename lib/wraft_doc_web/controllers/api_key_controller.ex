defmodule WraftDocWeb.Api.V1.ApiKeyController do
  @moduledoc """
  Controller for managing API keys.
  Allows organizations to create, list, update, and delete API keys for third-party integrations.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug(WraftDocWeb.Plug.AddActionLog)

  plug(WraftDocWeb.Plug.Authorized,
    create: "api_key:manage",
    index: "api_key:show",
    show: "api_key:show",
    update: "api_key:manage",
    delete: "api_key:delete",
    toggle_status: "api_key:manage"
  )

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ApiKeys
  alias WraftDoc.ApiKeys.ApiKey

  def swagger_definitions do
    %{
      ApiKeyRequest:
        swagger_schema do
          title("API Key Request")
          description("Request body to create an API key")

          properties do
            name(:string, "Descriptive name for the API key", required: true)
            user_id(:string, "User ID for authentication (defaults to current user)", required: false)
            expires_at(:string, "Optional: Expiration datetime (ISO-8601)", required: false)
            rate_limit(:integer, "Requests per hour limit", required: false)
            ip_whitelist(:array, "Optional: List of allowed IP addresses", required: false)
            metadata(:object, "Optional: Custom metadata as JSON", required: false)
          end

          example(%{
            name: "CRM Integration",
            rate_limit: 1000,
            metadata: %{
              integration_type: "salesforce",
              environment: "production"
            }
          })
        end,
      ApiKeyUpdateRequest:
        swagger_schema do
          title("API Key Update Request")
          description("Request body to update an API key")

          properties do
            name(:string, "Descriptive name for the API key", required: false)
            expires_at(:string, "Optional: Expiration datetime (ISO-8601)", required: false)
            rate_limit(:integer, "Requests per hour limit", required: false)
            ip_whitelist(:array, "Optional: List of allowed IP addresses", required: false)
            is_active(:boolean, "Enable or disable the key", required: false)
            metadata(:object, "Optional: Custom metadata as JSON", required: false)
          end

          example(%{
            name: "CRM Integration - Updated",
            is_active: true,
            rate_limit: 2000
          })
        end,
      ApiKeyResponse:
        swagger_schema do
          title("API Key Response")
          description("API key details")

          properties do
            id(:string, "API Key ID")
            name(:string, "API key name")
            key(:string, "The actual API key (only shown once during creation)")
            key_prefix(:string, "Key prefix for identification")
            expires_at(:string, "Expiration datetime")
            is_active(:boolean, "Whether the key is active")
            rate_limit(:integer, "Rate limit")
            ip_whitelist(:array, "IP whitelist")
            last_used_at(:string, "Last usage timestamp")
            usage_count(:integer, "Total usage count")
            metadata(:object, "Custom metadata")
            inserted_at(:string, "Creation timestamp")
            updated_at(:string, "Last update timestamp")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "CRM Integration",
            key: "wraft_a1b2c3d4_AbCdEfGhIjKlMnOpQrStUvWxYz123456",
            key_prefix: "a1b2c3d4",
            expires_at: nil,
            is_active: true,
            rate_limit: 1000,
            ip_whitelist: [],
            last_used_at: nil,
            usage_count: 0,
            metadata: %{integration_type: "salesforce"},
            inserted_at: "2024-11-18T10:00:00Z",
            updated_at: "2024-11-18T10:00:00Z"
          })
        end,
      ApiKeyIndex:
        swagger_schema do
          title("API Keys Index")
          description("List of API keys")

          properties do
            api_keys(Schema.array(:ApiKeyResponse))
            page_number(:integer, "Current page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of API keys")
          end

          example(%{
            api_keys: [
              %{
                id: "123e4567-e89b-12d3-a456-426614174000",
                name: "CRM Integration",
                key_prefix: "a1b2c3d4",
                is_active: true,
                rate_limit: 1000,
                usage_count: 150,
                last_used_at: "2024-11-18T09:30:00Z"
              }
            ],
            page_number: 1,
            total_pages: 1,
            total_entries: 1
          })
        end
    }
  end

  @doc """
  List all API keys for the current organization
  """
  swagger_path :index do
    get("/api_keys")
    summary("List API keys")
    description("List all API keys for the current organization")

    parameters do
      page(:query, :integer, "Page number", required: false)
    end

    response(200, "Ok", Schema.ref(:ApiKeyIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    %{
      entries: api_keys,
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    } = ApiKeys.list_api_keys(current_user, params)

    render(conn, "index.json",
      api_keys: api_keys,
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    )
  end

  @doc """
  Show a single API key
  """
  swagger_path :show do
    get("/api_keys/{id}")
    summary("Show an API key")
    description("Get details of a specific API key")

    parameters do
      id(:path, :string, "API Key ID", required: true)
    end

    response(200, "Ok", Schema.ref(:ApiKeyResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => api_key_id}) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id) do
      render(conn, "api_key.json", api_key: api_key)
    end
  end

  @doc """
  Create a new API key
  """
  swagger_path :create do
    post("/api_keys")
    summary("Create an API key")
    description("Create a new API key for third-party integrations")

    parameters do
      api_key(:body, Schema.ref(:ApiKeyRequest), "API key to create", required: true)
    end

    response(201, "Created", Schema.ref(:ApiKeyResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, %ApiKey{} = api_key} <- ApiKeys.create_api_key(current_user, params) do
      conn
      |> put_status(:created)
      |> render("api_key.json", api_key: api_key)
    end
  end

  @doc """
  Update an API key
  """
  swagger_path :update do
    put("/api_keys/{id}")
    summary("Update an API key")
    description("Update an existing API key")

    parameters do
      id(:path, :string, "API Key ID", required: true)
      api_key(:body, Schema.ref(:ApiKeyUpdateRequest), "API key updates", required: true)
    end

    response(200, "Ok", Schema.ref(:ApiKeyResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => api_key_id} = params) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id),
         {:ok, %ApiKey{} = updated_api_key} <- ApiKeys.update_api_key(api_key, params) do
      render(conn, "api_key.json", api_key: updated_api_key)
    end
  end

  @doc """
  Delete an API key
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api_keys/{id}")
    summary("Delete an API key")
    description("Permanently delete an API key")

    parameters do
      id(:path, :string, "API Key ID", required: true)
    end

    response(204, "No Content")
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => api_key_id}) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id),
         {:ok, %ApiKey{}} <- ApiKeys.delete_api_key(api_key) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
  Toggle API key active status
  """
  swagger_path :toggle_status do
    patch("/api_keys/{id}/toggle")
    summary("Toggle API key status")
    description("Enable or disable an API key")

    parameters do
      id(:path, :string, "API Key ID", required: true)
    end

    response(200, "Ok", Schema.ref(:ApiKeyResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec toggle_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def toggle_status(conn, %{"id" => api_key_id}) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id),
         {:ok, %ApiKey{} = updated_api_key} <- ApiKeys.toggle_api_key_status(api_key) do
      render(conn, "api_key.json", api_key: updated_api_key)
    end
  end
end

