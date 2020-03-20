defmodule WraftDocWeb.Api.V1.ResourceView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("create.json", %{resource: resource}) do
    %{
      id: resource.id,
      category: resource.category,
      action: resource.action
    }
  end

  def render("index.json", %{
        resources: resources,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      resources: render_many(resources, ResourceView, "create.json", as: :resource),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
