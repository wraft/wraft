defmodule WraftDocWeb.Api.V1.IntegrationController do
  use WraftDocWeb, :controller
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

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    integrations = Integrations.list_organisation_integrations(current_user)
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
