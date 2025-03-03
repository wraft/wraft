defmodule WraftDocWeb.Api.V1.OrganisationFieldController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.Authorized

  plug WraftDocWeb.Plug.AddActionLog,
    index: "organisation_field:show",
    create: "organisation_field:manage",
    show: "organisation_field:show",
    update: "organisation_field:manage",
    delete: "organisation_field:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents
  alias WraftDoc.Documents.OrganisationField

  def swagger_definitions do
    %{
      OrganisationFieldRequest:
        swagger_schema do
          title("Organisation Field Request")
          description("Create organisation field")

          properties do
            name(:string, "Name of the field", required: true)
            field_type_id(:string, "Id of the field type", required: true)
            meta(:map, "Attributes of the field")
            description(:application, "Field description")
          end

          example(%{
            name: "position",
            field_type_id: "asdlkne4781234123clk",
            meta: %{"src" => "/img/img.png", "alt" => "Image"},
            description: "text input"
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
        end,
      OrganisationFieldIndex:
        swagger_schema do
          title("Organisation field index")

          properties do
            members(Schema.ref(:OrganisationField))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end
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
         } <- Documents.list_organisation_fields(current_user, params) do
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

  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Documents.create_organisation_field(current_user, params) do
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

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Documents.get_organisation_field(id, current_user) do
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

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Documents.get_organisation_field(id, current_user),
         %OrganisationField{} = organisation_field <-
           Documents.update_organisation_field(
             current_user,
             organisation_field,
             params
           ) do
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

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with organisation_field <- Documents.show_organisation_field(id, current_user),
         {:ok, %OrganisationField{}} <-
           Documents.delete_organisation_field(organisation_field) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end
end
