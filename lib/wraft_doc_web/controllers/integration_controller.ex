defmodule WraftDocWeb.Api.V1.IntegrationController do
  @moduledoc """
  Controller for managing organization integrations.

  This controller handles CRUD operations for integrations, as well as
  enabling/disabling integrations and updating their event subscriptions.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.Integration
  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  plug WraftDocWeb.Plug.Authorized,
    index: "integration:show",
    create: "integration:manage",
    show: "integration:show",
    update: "integration:manage",
    delete: "integration:manage",
    enable: "integration:manage",
    disable: "integration:manage",
    update_events: "integration:manage"

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Integrations"])

  operation(:index,
    summary: "List integrations",
    description: "Returns a list of all integrations for the current organization",
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationsResponse},
      forbidden: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Lists all integrations for the current organization.

  Returns a list of all integration configurations that belong to the
  organization of the current user.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns.current_user

    integrations = Integrations.list_organisation_integrations(current_user)
    render(conn, "index.json", integrations: integrations)
  end

  operation(:create,
    summary: "Create integration",
    description: "Creates a new integration configuration for the current organization",
    request_body:
      {"Integration parameters", "application/json", Schemas.Integration.IntegrationCreateParams},
    responses: [
      created: {"Created", "application/json", Schemas.Integration.IntegrationResponse},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Creates a new integration for the current organization.

  Accepts integration parameters and creates a new integration configuration
  for the organization of the current user. Returns the created integration.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    organisation_id = conn.assigns.current_user.current_org_id
    integration_params = Map.put(params, "organisation_id", organisation_id)

    with {:ok, %Integration{} = integration} <-
           Integrations.create_integration(integration_params) do
      conn
      |> put_status(:created)
      |> render("show.json", integration: integration)
    end
  end

  operation(:show,
    summary: "Get integration",
    description: "Returns details of a specific integration by ID",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationResponse},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Shows details of a specific integration.

  Returns the details of the requested integration if it belongs to the
  current user's organization. Returns a 403 Forbidden error otherwise.
  """
  @spec show(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id do
      render(conn, "show.json", integration: integration)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end

  operation(:update,
    summary: "Update integration",
    description: "Updates an existing integration configuration",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    request_body:
      {"Integration parameters to update", "application/json",
       Schemas.Integration.IntegrationUpdateParams},
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationResponse},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Updates an existing integration.

  Updates the specified integration with the provided parameters if it
  belongs to the current user's organization. Returns a 403 Forbidden error otherwise.
  """
  @spec update(Plug.Conn.t(), %{required(String.t()) => String.t() | map()}) :: Plug.Conn.t()
  def update(conn, %{"id" => id, "integration" => integration_params}) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id,
         {:ok, %Integration{} = updated_integration} <-
           Integrations.update_integration(integration, integration_params) do
      render(conn, "show.json", integration: updated_integration)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end

  operation(:delete,
    summary: "Delete integration",
    description: "Deletes an integration configuration",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    responses: [
      no_content: {"No Content", "application/json", nil},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Deletes an integration.

  Permanently removes the specified integration if it belongs to the
  current user's organization. Returns a 403 Forbidden error otherwise.
  """
  @spec delete(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id,
         {:ok, %Integration{}} <- Integrations.delete_integration(integration) do
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end

  operation(:enable,
    summary: "Enable integration",
    description: "Enables a previously disabled integration",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationResponse},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Enables an integration.

  Sets the enabled status to true for the specified integration if it belongs
  to the current user's organization. Returns a 403 Forbidden error otherwise.
  """
  @spec enable(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
  def enable(conn, %{"id" => id}) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id,
         {:ok, %Integration{} = updated_integration} <-
           Integrations.enable_integration(integration) do
      render(conn, "show.json", integration: updated_integration)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end

  operation(:disable,
    summary: "Disable integration",
    description: "Disables an enabled integration",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationResponse},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Disables an integration.

  Sets the enabled status to false for the specified integration if it belongs
  to the current user's organization. Returns a 403 Forbidden error otherwise.
  """
  @spec disable(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
  def disable(conn, %{"id" => id}) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id,
         {:ok, %Integration{} = updated_integration} <-
           Integrations.disable_integration(integration) do
      render(conn, "show.json", integration: updated_integration)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end

  operation(:update_events,
    summary: "Update integration events",
    description: "Updates the event subscriptions for an integration",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    request_body:
      {"Event subscriptions to update", "application/json", Schemas.Integration.EventUpdateParams},
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationResponse},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Updates the event subscriptions for an integration.

  Updates the list of events that the integration subscribes to if it belongs
  to the current user's organization. Returns a 403 Forbidden error otherwise.
  """
  @spec update_events(Plug.Conn.t(), %{required(String.t()) => String.t() | [String.t()]}) ::
          Plug.Conn.t()
  def update_events(conn, %{"id" => id, "events" => events}) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id,
         {:ok, %Integration{} = updated_integration} <-
           Integrations.update_integration_events(integration, events) do
      render(conn, "show.json", integration: updated_integration)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end

  operation(:update_config,
    summary: "Update integration configuration",
    description: "Updates the configuration parameters of an existing integration",
    parameters: [
      id: [in: :path, type: :string, description: "Integration ID", required: true]
    ],
    request_body:
      {"New configuration values to update", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         example: %{
           "client_id" => "new-client-id-value",
           "client_secret" => "new-client-secret",
           "webhook_url" => "https://new-webhook-url.example.com"
         }
       }},
    responses: [
      ok: {"OK", "application/json", Schemas.Integration.IntegrationResponse},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Forbidden", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Updates the configuration of an integration if it belongs to the current user's organization.
  Returns a 403 Forbidden error otherwise.
  """
  @spec update_config(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_config(conn, %{"id" => id} = params) do
    user_organisation_id = conn.assigns.current_user.current_org_id

    with %Integration{organisation_id: organisation_id} = integration <-
           Integrations.get_integration(id),
         true <- user_organisation_id == organisation_id,
         {:ok, %Integration{} = updated_integration} <-
           Integrations.update_integration_config(integration, params) do
      render(conn, "show.json", integration: updated_integration)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})

      error ->
        error
    end
  end
end
