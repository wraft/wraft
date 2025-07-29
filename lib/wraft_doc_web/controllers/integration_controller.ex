defmodule WraftDocWeb.Api.V1.IntegrationController do
  use WraftDocWeb, :controller
  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.Integration

  plug WraftDocWeb.Plug.AddActionLog

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

  def index(conn, _params) do
    organisation_id = conn.assigns.current_user.current_org_id
    integrations = Integrations.list_organisation_integrations(organisation_id)
    render(conn, "index.json", integrations: integrations)
  end

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

  def show(conn, %{"id" => id}) do
    organisation_id = conn.assigns.current_user.current_org_id

    try do
      integration = Integrations.get_integration!(id)

      if integration.organisation_id != organisation_id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})
      else
        render(conn, "show.json", integration: integration)
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration not found"})
    end
  end

  def update(conn, %{"id" => id, "integration" => integration_params}) do
    organisation_id = conn.assigns.current_user.current_org_id

    try do
      integration = Integrations.get_integration!(id)

      if integration.organisation_id != organisation_id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})
      else
        with {:ok, %Integration{} = updated_integration} <-
               Integrations.update_integration(integration, integration_params) do
          render(conn, "show.json", integration: updated_integration)
        end
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration not found"})
    end
  end

  def delete(conn, %{"id" => id}) do
    organisation_id = conn.assigns.current_user.current_org_id

    try do
      integration = Integrations.get_integration!(id)

      if integration.organisation_id != organisation_id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})
      else
        with {:ok, %Integration{}} <- Integrations.delete_integration(integration) do
          send_resp(conn, :no_content, "")
        end
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration not found"})
    end
  end

  def enable(conn, %{"id" => id}) do
    organisation_id = conn.assigns.current_user.current_org_id

    try do
      integration = Integrations.get_integration!(id)

      # Check if integration belongs to current organization
      if integration.organisation_id != organisation_id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})
      else
        with {:ok, %Integration{} = updated_integration} <-
               Integrations.enable_integration(integration) do
          render(conn, "show.json", integration: updated_integration)
        end
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration not found"})
    end
  end

  def disable(conn, %{"id" => id}) do
    organisation_id = conn.assigns.current_user.current_org_id

    try do
      integration = Integrations.get_integration!(id)

      if integration.organisation_id != organisation_id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})
      else
        with {:ok, %Integration{} = updated_integration} <-
               Integrations.disable_integration(integration) do
          render(conn, "show.json", integration: updated_integration)
        end
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration not found"})
    end
  end

  def update_events(conn, %{"id" => id, "events" => events}) do
    organisation_id = conn.assigns.current_user.current_org_id

    try do
      integration = Integrations.get_integration!(id)

      if integration.organisation_id != organisation_id do
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Integration does not belong to current organization"})
      else
        with {:ok, %Integration{} = updated_integration} <-
               Integrations.update_integration_events(integration, events) do
          render(conn, "show.json", integration: updated_integration)
        end
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration not found"})
    end
  end
end
