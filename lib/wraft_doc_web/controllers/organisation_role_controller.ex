defmodule WraftDocWeb.Api.V1.OrganisationRoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  alias WraftDoc.{Enterprise}
  alias WraftDoc.Account.Role

  def swagger_definitions do
    %{
      ListofRoles:
        swagger_schema do
          title("Role of the user")
          description("Role for the user")

          properties do
            id(:string, "Id of the role")
            name(:string, "Name of the role")
          end
        end,
      OrganisationRole:
        swagger_schema do
          title("Organisation Role Request")
          description("Role under the organisation")

          properties do
            id(:string, "The id of an organisation", required: true)
            roles(Schema.ref(:ListofRoles))
          end
        end
    }
  end

  swagger_path :show do
    get("/organisation/{id}/roles")
    summary("show an organisation roles")
    description("API to list the roles under the organisation")

    parameters do
      id(:path, :string, "organisation_id", required: true)
    end

    response(200, "Ok", Schema.ref(:OrganisationRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => uuid}) do
    organisation_role = Enterprise.get_organisation_id_roles(uuid)

    conn
    |> render("organisation_role.json", organisation_role: organisation_role)
  end

  swagger_path :create_organisation_roles do
    post("/organisation/{id}/roles")
    summary("Create an organisation roles")
    description("create the role under the organisation")

    parameters do
      id(:path, :string, "organisation_id", required: true)
    end

    response(200, "Ok", Schema.ref(:OrganisationRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def create_organisation_roles(conn, %{"id" => id} = params) do
    organisation_role = Enterprise.create_organisation_role(id, params)

    conn
    |> render("organisation_role.json", organisation_role: organisation_role)
  end

  swagger_path :delete_organisation_role do
    delete("/organisation/{o_id}/roles/{id}")
    summary("show an organisation roles")
    description("API to list the roles under the organisation")

    parameters do
      id(:path, :string, "role_id", required: true)
      o_id(:path, :string, "organisation_id", required: true)
    end

    response(200, "Ok", Schema.ref(:OrganisationRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete_organisation_role(conn, %{"id" => id, "o_id" => o_id}) do
    with %Role{} = role <- Enterprise.get_role_of_the_organisation(id, o_id),
         %Role{} = role <- Enterprise.delete_role_of_the_organisation(role) do
      conn |> render("role.json", role: role)
    end
  end
end
