defmodule WraftDocWeb.Api.V1.RoleView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{ContentTypeView, OrganisationView}

  def render("role.json", %{role: role}) do
    %{
      id: role.id,
      name: role.name
    }
  end

  def render("show.json", %{role: role}) do
    %{
      id: role.id,
      name: role.name,
      organisation: render_one(role.organisation, OrganisationView, "organisation.json"),
      content_types: render_many(role.content_types, ContentTypeView, "role_content_type.json")
    }
  end
end
