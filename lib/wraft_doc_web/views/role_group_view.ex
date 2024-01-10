defmodule WraftDocWeb.Api.V1.RoleGroupView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.RoleView

  def render("role_group.json", %{role_group: role_group}) do
    %{
      id: role_group.id,
      name: role_group.name,
      description: role_group.description,
      inserted_at: role_group.inserted_at,
      updated_at: role_group.updated_at
    }
  end

  def render("show.json", %{role_group: role_group}) do
    %{
      role_group: render_one(role_group, __MODULE__, "role_group.json", as: :role_group),
      roles: render_many(role_group.roles, RoleView, "role.json", as: :role)
    }
  end

  def render("index.json", %{role_groups: role_groups}) do
    %{role_groups: render_many(role_groups, __MODULE__, "role_group.json", as: :role_group)}
  end
end
