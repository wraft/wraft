defmodule WraftDocWeb.Api.V1.RoleGroupView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.RoleView

  def render("role_group.json", %{role_group: role_group}) do
    %{
      id: role_group.id,
      name: role_group.name,
      description: role_group.description,
      inserted_at: role_group.inserted_at,
      updated_at: role_group.updated_at,
      roles: render_many(role_group.roles, RoleView, "role.json", as: :role)
    }
  end
end
