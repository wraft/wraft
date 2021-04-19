defmodule WraftDocWeb.Api.V1.OrganisationFieldController do
  use WraftDocWeb, :controller

  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{
    Document,
    Document.FieldType,
    Document.OrganisationField
  }

  use PhoenixSwagger

  def swagger_definitions do
    %{
      OrganisationFieldRequest:
        swagger_schema do
          title("Organisation Field Request")
          description("Create organisation field")

          properties do
            name(:string, "Name of the field", required: true)
            field_type_uuid(:string, "Id of the field type", required: true)
            meta(:map, "Attributes of the field")
            description(:application, "Field description")
          end

          example(%{
            name: "position",
            field_type_uuid: "asdlkne4781234123clk",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            descrtiption: "text input"
          })
        end,
      OrganisationField:
        swagger_schema do
          title("Organisation field in response")
          description("Organisation field in respone.")

          properties do
            id(:string, "ID of Organisation field")
            name(:string, "Name of Organisation field")
            meta(:map, "Attributes of the field")
            field_type(Schema.ref(:FieldType))
          end

          example(%{
            name: "position",
            field_type_id: "asdlkne4781234123clk",
            meta: %{"src" => "/img/img.png", "alt" => "Image"}
          })
        end,
      OrganisationFields:
        swagger_schema do
          title("Field response array")
          description("List of field type in response.")
          type(:array)
          items(Schema.ref(:OrganisationField))
        end
    }
  end

  swagger_path :index do
    get("/organisation-fields")
    summary("Organisation field index")
    description("API to get the list of all organisation fields created so far")
    parameter(:page, :query, :string, "Page number")
    response(200, "Ok", Schema.ref(:OrganisationFieldIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: organisation_fields,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.list_organisation_fields(current_user, params) do
      render(conn, "index.json",
        organisation_fields: organisation_fields,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Create a organisation field.
  """
  swagger_path :create do
    post("/organisation-fields")
    summary("Create organisation field")
    description("Create organisation field API")

    parameters do
      organisation_field(
        :body,
        Schema.ref(:OrganisationFieldRequest),
        "Organisation field to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:OrganisationField))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, %{"field_type_uuid" => field_type_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %FieldType{} = field_type <- Document.get_field_type(field_type_uuid, current_user),
         %OrganisationField{} = organisation_field <-
           Document.create_organisation_field(current_user, field_type, params) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end

  @doc """
  Show a Content Type.
  """
  swagger_path :show do
    get("/organisation-fields/{id}")
    summary("Show a Organisation fields")
    description("API to show details of a organisation field")

    parameters do
      id(:path, :string, "organisation field id", required: true)
    end

    response(200, "Ok", Schema.ref(:OrganisationField))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Document.get_organisation_field(uuid, current_user) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end

  @doc """
  Api to update an organisation field
  """
  swagger_path :update do
    put("/organisation-fields/{id}")
    summary("Update an Organisation field")
    description("API to update an organisation field")

    parameters do
      id(:path, :string, "content type id", required: true)

      layout(:body, Schema.ref(:OrganisationFieldRequest), "Organisation to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:OrganisationField))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def update(conn, %{"id" => uuid, "field_type_uuid" => field_type_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %FieldType{} = field_type <- Document.get_field_type(field_type_uuid, current_user),
         %OrganisationField{} = organisation_field <-
           Document.get_organisation_field(uuid, current_user),
         %OrganisationField{} = organisation_field <-
           Document.update_organisation_field(
             current_user,
             organisation_field,
             field_type,
             params
           ) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end

  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Document.get_organisation_field(uuid, current_user),
         %OrganisationField{} = organisation_field <-
           Document.update_organisation_field(current_user, organisation_field, params) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end

  @doc """
  Delete an Organisation field.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/organisation-fields/{id}")
    summary("Delete an organisation field")
    description("API to delete an organisation field")

    parameters do
      id(:path, :string, "organisation field id", required: true)
    end

    response(200, "Ok", Schema.ref(:OrganisationField))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with organisation_field <- Document.get_organisation_field(uuid, current_user),
         {:ok, %OrganisationField{} = organisation_field} <-
           Document.delete_organisation_field(organisation_field) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end
end
