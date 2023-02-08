defmodule WraftDocWeb.Api.V1.RoleView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{ContentTypeView, OrganisationView}

  def render("role.json", %{role: role}) do
    %{
      id: role.id,
      name: role.name,
      permissions: role.permissions
    }
  end

  def render("index.json", %{roles: roles}) do
    render_many(roles, __MODULE__, "role.json", as: :role)
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
