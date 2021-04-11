defmodule WraftDocWeb.Api.V1.RoleView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.ContentTypeView

  def render("role.json", %{role: role}) do
    %{
      id: role.uuid,
      name: role.name
    }
  end

  def render("show.json", %{role: role}) do
    %{
      id: role.uuid,
      name: role.name,
      content_type: render_many(role.content_types, ContentTypeView, "role_content_type.json")
    }
  end
end
