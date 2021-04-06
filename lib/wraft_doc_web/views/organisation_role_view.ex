defmodule WraftDocWeb.Api.V1.OrganisationRoleView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.RoleView

  def render("organisation_role.json", %{organisation_role: organisation_role}) do
    %{
      id: organisation_role.uuid,
      organisation_id: organisation_role.uuid,
      role: render_many(organisation_role.roles, RoleView, "role.json")
    }
  end

  def render("role.json", %{role: role}) do
    %{
      id: role.uuid,
      name: role.name
    }
  end
end
