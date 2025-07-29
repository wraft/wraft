defmodule WraftDocWeb.Api.V1.IntegrationView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.IntegrationView

  def render("index.json", %{integrations: integrations}) do
    render_many(integrations, IntegrationView, "integration.json")
  end

  def render("show.json", %{integration: integration}) do
    %{data: render_one(integration, IntegrationView, "integration.json")}
  end

  def render("integration.json", %{integration: integration}) do
    %{
      id: integration.id,
      provider: integration.provider,
      name: integration.name,
      category: integration.category,
      enabled: integration.enabled,
      events: integration.events,
      metadata: integration.metadata,
      inserted_at: integration.inserted_at,
      updated_at: integration.updated_at
    }
  end
end
