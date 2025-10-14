defmodule WraftDocWeb.Api.V1.IntegrationController do
  @moduledoc """
  Controller for managing organization integrations.

  This controller handles CRUD operations for integrations, as well as
  enabling/disabling integrations and updating their event subscriptions.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.Integration

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

  def swagger_definitions do
    %{
      Integration:
        swagger_schema do
          title("Integration")
          description("An integration with an external service")

          properties do
            id(:string, "Integration identifier", format: "uuid")
            provider(:string, "Integration provider name", required: true)
            name(:string, "Display name of the integration", required: true)
            category(:string, "Category the integration belongs to", required: true)
            enabled(:boolean, "Whether the integration is enabled", required: true)
            events(:array, "List of events this integration subscribes to")
            metadata(:object, "Additional metadata about the integration")
            inserted_at(:string, "When the integration was created", format: "date-time")
            updated_at(:string, "When the integration was last updated", format: "date-time")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            provider: "slack",
            name: "Slack",
            category: "communication",
            enabled: true,
            events: ["document.created", "document.signed"],
            metadata: %{},
            inserted_at: "2023-01-01T12:00:00Z",
            updated_at: "2023-01-01T12:30:00Z"
          })
        end,
      IntegrationResponse:
        swagger_schema do
          title("Integration Response")
          description("Response containing a single integration")

          properties do
            data(Schema.ref(:Integration), "The integration")
          end
        end,
      IntegrationsResponse:
        swagger_schema do
          title("Integrations List Response")
          description("Response containing a list of integrations")
          type(:array)
          items(Schema.ref(:Integration))
        end,
      IntegrationCreateParams:
        swagger_schema do
          title("Integration Create Parameters")
          description("Parameters for creating a new integration")

          properties do
            provider(:string, "Integration provider identifier", required: true)
            name(:string, "Display name for the integration", required: true)
            category(:string, "Category the integration belongs to", required: true)
            config(:object, "Configuration parameters for the integration", required: true)
            events(:array, "List of events to subscribe to", items: %{type: :string})
          end

          example(%{
            provider: "slack",
            name: "Team Slack",
            category: "communication",
            config: %{
              "bot_token" => "xoxb-1234567890-abcdefghij",
              "signing_secret" => "abcdef1234567890"
            },
            events: ["document.created", "document.signed"]
          })
        end,
      IntegrationUpdateParams:
        swagger_schema do
          title("Integration Update Parameters")
          description("Parameters for updating an existing integration")

          properties do
            integration(:object, "Integration parameters to update",
              required: true,
              properties: %{
                name: %{type: :string, description: "Display name for the integration"},
                config: %{type: :object, description: "Configuration parameters"},
                enabled: %{type: :boolean, description: "Whether the integration is enabled"}
              }
            )
          end
        end,
      EventUpdateParams:
        swagger_schema do
          title("Events Update Parameters")
          description("Parameters for updating integration event subscriptions")

          properties do
            events(:array, "List of events to subscribe to",
              required: true,
              items: %{type: :string}
            )
          end

          example(%{
            events: ["document.created", "document.signed"]
          })
        end,
      Error:
        swagger_schema do
          title("Error Response")
          description("Error response when something goes wrong")

          properties do
            error(:string, "Error message")
          end

          example(%{
            error: "Integration does not belong to current organization"
          })
        end
    }
  end

  swagger_path :index do
    get("/integrations")
    summary("List integrations")
    description("Returns a list of all integrations for the current organization")

    tag("Integrations")

    response(200, "OK", Schema.ref(:IntegrationsResponse))
    response(403, "Unauthorized")
  end

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

  swagger_path :create do
    post("/integrations/new")
    summary("Create integration")
    description("Creates a new integration configuration for the current organization")

    parameters do
      body(:body, Schema.ref(:IntegrationCreateParams), "Integration parameters", required: true)
    end

    tag("Integrations")

    response(201, "Created", Schema.ref(:IntegrationResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

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

  swagger_path :show do
    get("/integrations/{id}")
    summary("Get integration")
    description("Returns details of a specific integration by ID")

    parameters do
      id(:path, :string, "Integration ID", required: true)
    end

    tag("Integrations")

    response(200, "OK", Schema.ref(:IntegrationResponse))
    response(403, "Unauthorized")
    response(403, "Forbidden", Schema.ref(:Error))
    response(404, "Not Found")
  end

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

  swagger_path :update do
    put("/integrations/{id}")
    summary("Update integration")
    description("Updates an existing integration configuration")

    parameters do
      id(:path, :string, "Integration ID", required: true)

      body(:body, Schema.ref(:IntegrationUpdateParams), "Integration parameters to update",
        required: true
      )
    end

    tag("Integrations")

    response(200, "OK", Schema.ref(:IntegrationResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(403, "Forbidden", Schema.ref(:Error))
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

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

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/integrations/{id}")
    summary("Delete integration")
    description("Deletes an integration configuration")

    parameters do
      id(:path, :string, "Integration ID", required: true)
    end

    tag("Integrations")

    response(204, "No Content")
    response(403, "Unauthorized")
    response(403, "Forbidden", Schema.ref(:Error))
    response(404, "Not Found")
  end

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

  swagger_path :enable do
    put("/integrations/{id}/enable")
    summary("Enable integration")
    description("Enables a previously disabled integration")

    parameters do
      id(:path, :string, "Integration ID", required: true)
    end

    tag("Integrations")

    response(200, "OK", Schema.ref(:IntegrationResponse))
    response(403, "Unauthorized")
    response(403, "Forbidden", Schema.ref(:Error))
    response(404, "Not Found")
  end

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

  swagger_path :disable do
    put("/integrations/{id}/disable")
    summary("Disable integration")
    description("Disables an enabled integration")

    parameters do
      id(:path, :string, "Integration ID", required: true)
    end

    tag("Integrations")

    response(200, "OK", Schema.ref(:IntegrationResponse))
    response(403, "Unauthorized")
    response(403, "Forbidden", Schema.ref(:Error))
    response(404, "Not Found")
  end

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

  swagger_path :update_events do
    put("/integrations/{id}/events")
    summary("Update integration events")
    description("Updates the event subscriptions for an integration")

    parameters do
      id(:path, :string, "Integration ID", required: true)
      body(:body, Schema.ref(:EventUpdateParams), "Event subscriptions to update", required: true)
    end

    response(200, "OK", Schema.ref(:IntegrationResponse))
    response(403, "Unauthorized")
    response(403, "Forbidden", Schema.ref(:Error))
    response(404, "Not Found")
    response(422, "Unprocessable Entity")

    tag("Integrations")
  end

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
end
