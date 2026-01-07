defmodule WraftDocWeb.Api.V1.ApiKeyController do
  @moduledoc """
  Controller for managing API keys.
  Allows organizations to create, list, update, and delete API keys for third-party integrations.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

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

  alias WraftDocWeb.Schemas.ApiKey, as: ApiKeySpec
  alias WraftDocWeb.Schemas.Error

  tags(["API Keys"])

  operation(:index,
    summary: "List API keys",
    description: "List all API keys for the current organization",
    parameters: [
      page: [in: :query, type: :integer, description: "Page number", required: false]
    ],
    responses: [
      ok: {"Ok", "application/json", ApiKeySpec.ApiKeyIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:show,
    summary: "Show an API key",
    description: "Get details of a specific API key",
    parameters: [
      id: [in: :path, type: :string, description: "API Key ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ApiKeySpec.ApiKeyResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => api_key_id}) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id) do
      render(conn, "api_key.json", api_key: api_key)
    end
  end

  operation(:create,
    summary: "Create an API key",
    description: "Create a new API key for third-party integrations",
    request_body: {"API key to create", "application/json", ApiKeySpec.ApiKeyRequest},
    responses: [
      created: {"Created", "application/json", ApiKeySpec.ApiKeyResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, %ApiKey{} = api_key} <- ApiKeys.create_api_key(current_user, params) do
      conn
      |> put_status(:created)
      |> render("api_key.json", api_key: api_key)
    end
  end

  operation(:update,
    summary: "Update an API key",
    description: "Update an existing API key",
    parameters: [
      id: [in: :path, type: :string, description: "API Key ID", required: true]
    ],
    request_body: {"API key updates", "application/json", ApiKeySpec.ApiKeyUpdateRequest},
    responses: [
      ok: {"Ok", "application/json", ApiKeySpec.ApiKeyResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => api_key_id} = params) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id),
         {:ok, %ApiKey{} = updated_api_key} <- ApiKeys.update_api_key(api_key, params) do
      render(conn, "api_key.json", api_key: updated_api_key)
    end
  end

  operation(:delete,
    summary: "Delete an API key",
    description: "Permanently delete an API key",
    parameters: [
      id: [in: :path, type: :string, description: "API Key ID", required: true]
    ],
    responses: [
      no_content: "No Content",
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => api_key_id}) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id),
         {:ok, %ApiKey{}} <- ApiKeys.delete_api_key(api_key) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:toggle_status,
    summary: "Toggle API key status",
    description: "Enable or disable an API key",
    parameters: [
      id: [in: :path, type: :string, description: "API Key ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ApiKeySpec.ApiKeyResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec toggle_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def toggle_status(conn, %{"id" => api_key_id}) do
    current_user = conn.assigns.current_user

    with %ApiKey{} = api_key <- ApiKeys.get_api_key(current_user, api_key_id),
         {:ok, %ApiKey{} = updated_api_key} <- ApiKeys.toggle_api_key_status(api_key) do
      render(conn, "api_key.json", api_key: updated_api_key)
    end
  end
end
