defmodule WraftDocWeb.Api.V1.OrganisationRoleView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.RoleView


  def render("organisation_role.json", %{organisation_role: organisation_role}) do
    %{
      id: organisation_role.uuid,
      role: render_many(organisation_role.roles, RoleView, "role.json")
    }
  end

  def render("organisation.json", %{organisation_role: organisation_role}) do
    %{
      id: organisation_role.uuid,
      organisation_id: organisation_role.organisation_id,
      role_id: organisation_role.role_id
    }
  end

  def render("role.json", %{role: role}) do
    %{
      id: role.uuid,
      name: role.name,
      role: render_many(role.role, RoleView, "role.json")
    }
  end

  def render("organisations.json", %{organisation_role: organisation_role}) do
    %{
      id: organisation_role.uuid,
      name: organisation_role.name
    }
  end
end
