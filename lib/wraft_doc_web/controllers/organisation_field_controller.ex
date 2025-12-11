defmodule WraftDocWeb.Api.V1.OrganisationFieldController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

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
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.OrganisationField, as: OrganisationFieldSchema

  tags(["OrganisationFields"])

  operation(:index,
    summary: "Organisation field index",
    description: "API to get the list of all organisation fields created so far",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", OrganisationFieldSchema.OrganisationFieldIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:create,
    summary: "Create organisation field",
    description: "Create organisation field API",
    request_body:
      {"Organisation field to be created", "application/json",
       OrganisationFieldSchema.OrganisationFieldRequest},
    responses: [
      ok: {"Ok", "application/json", OrganisationFieldSchema.OrganisationField},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Documents.create_organisation_field(current_user, params) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end

  operation(:show,
    summary: "Show a Organisation fields",
    description: "API to show details of a organisation field",
    parameters: [
      id: [in: :path, type: :string, description: "organisation field id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", OrganisationFieldSchema.OrganisationField},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %OrganisationField{} = organisation_field <-
           Documents.get_organisation_field(id, current_user) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end

  operation(:update,
    summary: "Update an Organisation field",
    description: "API to update an organisation field",
    parameters: [
      id: [in: :path, type: :string, description: "content type id", required: true]
    ],
    request_body:
      {"Organisation to be updated", "application/json",
       OrganisationFieldSchema.OrganisationFieldRequest},
    responses: [
      ok: {"Ok", "application/json", OrganisationFieldSchema.OrganisationField},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:delete,
    summary: "Delete an organisation field",
    description: "API to delete an organisation field",
    parameters: [
      id: [in: :path, type: :string, description: "organisation field id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", OrganisationFieldSchema.OrganisationField},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with organisation_field <- Documents.show_organisation_field(id, current_user),
         {:ok, %OrganisationField{}} <-
           Documents.delete_organisation_field(organisation_field) do
      render(conn, "show.json", organisation_field: organisation_field)
    end
  end
end
