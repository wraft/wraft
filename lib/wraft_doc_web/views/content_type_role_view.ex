defmodule WraftDocWeb.Api.V1.ContentTypeRoleView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.RoleView

  def render("show.json", %{content_type_role: content_type_role}) do
    %{
      id: content_type_role.uuid,
      name: content_type_role.name,
      decription: content_type_role.description,
      color: content_type_role.color,
      prefix: content_type_role.prefix,
      role: render_many(content_type_role.roles, RoleView, "role.json", as: :role)
    }
  end
end
