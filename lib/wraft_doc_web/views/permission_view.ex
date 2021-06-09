defmodule WraftDocWeb.Api.V1.PermissionView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.ResourceView

  def render("create.json", %{permission: permission}) do
    key = "#{permission.resource.category}_#{permission.resource.action}"

    %{
      "#{key}": [
        permission.role.name
      ]
    }
  end

  def render("index.json", %{
        permissions: permissions
      }) do
    %{
      permissions: render_many(permissions, PermissionView, "permission.json", as: :permission)
    }
  end

  def render("permission.json", %{permission: permission}) do
    %{
      "#{permission.label}":
        render_many(permission.resources, ResourceView, "show.json", as: :resource)
    }
  end

  # def render("permission.json", %{resource: resource}) do
  #   key = "#{resource.category}_#{resource.action}"

  #   %{
  #     "#{key}":
  #       render_many(resource.permissions, PermissionView, "permission_role.json", as: :permission)
  #   }
  # end

  def render("permission_role.json", %{permission: permission}) do
    %{
      id: permission.role.id,
      name: permission.role.name,
      permission: %{
        id: permission.id,
        resource_id: permission.resource_id
      }
    }
  end

  def render("delete.json", %{permission: permission}) do
    %{
      id: permission.id,
      resource_id: permission.resource_id,
      role_id: permission.role_id
    }
  end
end
