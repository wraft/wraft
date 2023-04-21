defmodule WraftDocWeb.Api.V1.PermissionView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("index.json", %{permissions_by_resource: permissions_by_resource}) do
    permissions_by_resource
    |> Enum.map(fn {resource, permissions} ->
      {resource, render_many(permissions, PermissionView, "permission.json", as: :permission)}
    end)
    |> Enum.into(%{})
  end

  def render("permission.json", %{permission: permission}) do
    %{
      id: permission.id,
      name: permission.name,
      action: permission.action
    }
  end
end
