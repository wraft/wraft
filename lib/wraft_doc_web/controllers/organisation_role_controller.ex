defmodule WraftDocWeb.Api.V1.OrganisationRoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  alias WraftDoc.{Enterprise, Enterprise.OrganisationRole}
  alias WraftDoc.Account.Role

  def show(conn, %{"id" => uuid}) do
    organisation_role = Enterprise.get_organisation_id_roles(uuid)

    conn
    |> render("organisation_role.json", organisation_role: organisation_role)
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, %OrganisationRole{} = organisation_role} <-
           Enterprise.create_organisation_role(current_user, params) do
      conn
      |> put_status(:created)
      |> render("organisation_role.json", organisation_role: organisation_role)
    end
  end

  def update(conn, %{"id" => uuid} = params) do
    with %OrganisationRole{} = organisation_role <- Enterprise.get_organisation(uuid),
         {:ok, %OrganisationRole{} = organisation_role} <-
           Enterprise.update_organisation_role(organisation_role, params) do
      conn
      |> put_status(:created)
      |> render("organisation_role.json", organisation_role: organisation_role)
    end
  end

  def delete_organisation_role(conn, %{"id" => id, "o_id" => o_id}) do
    with %Role{} = role <- Enterprise.get_role_of_the_organisation(id, o_id),
         %Role{} = role <- Enterprise.delete_role_of_the_organisation(role) do
      conn |> render("role.json", role: role)
    end
  end
end
