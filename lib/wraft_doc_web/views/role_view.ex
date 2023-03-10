defmodule WraftDocWeb.Api.V1.RoleView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.OrganisationView

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
      permissions: role.permissions,
      organisation: render_one(role.organisation, OrganisationView, "organisation.json")
    }
  end

  def render("assign_role.json", %{}) do
    %{
      info: "Assigned the given role to the user successfully.!"
    }
  end
end
