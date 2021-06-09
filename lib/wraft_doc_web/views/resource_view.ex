defmodule WraftDocWeb.Api.V1.ResourceView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.RoleView

  def render("show.json", %{resource: resource}) do
    %{
      id: resource.id,
      name: resource.name,
      action: resource.action,
      roles: render_many(resource.roles, RoleView, "role.json", as: :role)
    }
  end

  def render("create.json", %{resource: resource}) do
    %{
      id: resource.id,
      action: resource.action,
      name: resource.name
    }
  end

  def render("index.json", %{
        resources: resources
      }) do
    %{
      resources: render_many(resources, ResourceView, "resource.json", as: :resource)
    }
  end

  def render("resource.json", %{resource: resource}) do
    %{
      "#{resource.label}":
        render_many(resource.resources, ResourceView, "create.json", as: :resource)
    }
  end
end
