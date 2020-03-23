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
    %{
      id: permission.role.uuid,
      name: permission.role.name,
      permission: %{
        id: permission.uuid,
        resource_id: permission.resource_id
      }
    }
  end

  def render("delete.json", %{permission: permission}) do
    %{
      id: permission.uuid,
      resource_id: permission.resource_id,
      role_id: permission.role_id
    }
  end
end
