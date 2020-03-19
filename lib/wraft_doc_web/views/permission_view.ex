defmodule WraftDocWeb.Api.V1.PermissionView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("create.json", %{permission: permission}) do
    key = "#{permission.resource.category}_#{permission.resource.action}"

    %{
      "#{key}": [
        permission.role.name
      ]
    }
  end

  def render("index.json", %{
        resources: resources,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      permissions: render_many(resources, PermissionView, "permission.json", as: :resource),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("permission.json", %{resource: resource}) do
    key = "#{resource.category}_#{resource.action}"

    %{
      "#{key}":
        render_many(resource.permissions, PermissionView, "permission_role.json", as: :permission)
    }
  end

  def render("permission_role.json", %{permission: permission}) do
    permission.role.name
  end
end
