defmodule WraftDocWeb.Api.V1.ContentTypeRoleView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{RoleView, ContentTypeView}

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

  def render("show_content_type.json", %{content_type_role: content_type_role}) do
    %{
      uuid: content_type_role.uuid
    }
  end

  def render("create_content_type.json", %{content_type_role: content_type_role}) do
    %{
      uuid: content_type_role.uuid,
      role: render_one(content_type_role.role, RoleView, "role.json", as: :role),
      content_type:
        render_one(content_type_role.content_type, ContentTypeView, "role_content_type.json",
          as: :content_type
        )
    }
  end
end
