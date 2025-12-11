defmodule WraftDocWeb.Api.V1.CollectionFormController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.CollectionForms
  alias WraftDoc.CollectionForms.CollectionForm
  alias WraftDocWeb.Schemas.CollectionForm, as: CollectionFormSchema
  alias WraftDocWeb.Schemas.Error

  action_fallback(WraftDocWeb.FallbackController)

  tags(["CollectionForms"])

  operation(:show,
    summary: "Show an collection form",
    description: "API to get all details of an collection form",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the collection form", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", CollectionFormSchema.CollectionFormShow},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def show(conn, %{"id" => collection_form_id}) do
    with %CollectionForm{} = collection_form <-
           CollectionForms.get_collection_form(conn.assigns.current_user, collection_form_id) do
      render(conn, "show.json", collection_form: collection_form)
    end
  end

  operation(:create,
    summary: "Create an collection form api",
    description: "Create an collection form api",
    operation_id: "create_collection_forms",
    request_body:
      {"Collection Form to be created", "application/json",
       CollectionFormSchema.CollectionFormRequest},
    responses: [
      ok: {"Ok", "application/json", CollectionFormSchema.CollectionFormShow},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def create(conn, params) do
    with %CollectionForm{} = collection_form <-
           CollectionForms.create_collection_form(conn.assigns.current_user, params) do
      render(conn, "create.json", collection_form: collection_form)
    end
  end

  operation(:update,
    summary: "Update a Collection Form",
    description: "API to update a collection form",
    parameters: [
      id: [in: :path, type: :string, description: "collection form id", required: true]
    ],
    request_body:
      {"Collection Form to be updated", "application/json",
       CollectionFormSchema.CollectionFormRequest},
    responses: [
      ok: {"Ok", "application/json", CollectionFormSchema.CollectionFormShow},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    with %CollectionForm{} = collection_form <-
           CollectionForms.get_collection_form(conn.assigns.current_user, id),
         %CollectionForm{} = collection_form <-
           CollectionForms.update_collection_form(collection_form, params) do
      render(conn, "create.json", collection_form: collection_form)
    end
  end

  operation(:delete,
    summary: "Delete a Collection Form",
    description: "API to delete a collection form",
    parameters: [
      id: [in: :path, type: :string, description: "collection form id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", CollectionFormSchema.CollectionFormShow},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with %CollectionForm{} = collection_form <-
           CollectionForms.get_collection_form(conn.assigns.current_user, id),
         {:ok, collection_form} <- CollectionForms.delete_collection_form(collection_form) do
      render(conn, "collection_form.json", collection_form: collection_form)
    end
  end

  operation(:index,
    summary: "show all the collection forms",
    description: "API to show all the collection forms with preloaded collection form fields",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", CollectionFormSchema.CollectionFormIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def index(conn, params) do
    with %{
           entries: collection_forms,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- CollectionForms.list_collection_form(conn.assigns.current_user, params) do
      render(conn, "index.json",
        collection_forms: collection_forms,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
