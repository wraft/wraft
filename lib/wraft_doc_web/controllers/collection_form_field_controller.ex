defmodule WraftDocWeb.Api.V1.CollectionFormFieldController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.CollectionForms
  alias WraftDoc.CollectionForms.CollectionForm
  alias WraftDoc.CollectionForms.CollectionFormField
  alias WraftDocWeb.Schemas.CollectionFormField, as: CollectionFormFieldSchema
  alias WraftDocWeb.Schemas.Error

  tags(["CollectionFormFields"])

  operation(:show,
    summary: "Show an collection form fields",
    description: "API to get all details of an collection form fields",
    parameters: [
      c_form_id: [in: :path, type: :string, description: "Collection Form ID", required: true],
      id: [
        in: :path,
        type: :string,
        description: "ID of the collection form fields",
        required: true
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", CollectionFormFieldSchema.CollectionFormFieldShow},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => collection_form_id}) do
    with %CollectionFormField{} = collection_form_field <-
           CollectionForms.get_collection_form_field(
             conn.assigns.current_user,
             collection_form_id
           ) do
      render(conn, "show.json", collection_form_field: collection_form_field)
    end
  end

  operation(:create,
    summary: "Create an collection form fields api",
    description: "Create an collection form fields api",
    operation_id: "create_collection_forms_fields",
    parameters: [
      c_form_id: [in: :path, type: :string, description: "Collection Form ID", required: true]
    ],
    request_body:
      {"Collection Form Field to be created", "application/json",
       CollectionFormFieldSchema.CollectionFormFieldRequest},
    responses: [
      ok: {"Ok", "application/json", CollectionFormFieldSchema.CollectionFormFieldShow},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"c_form_id" => c_form_id} = params) do
    with %CollectionForm{} <-
           CollectionForms.get_collection_form(conn.assigns.current_user, c_form_id),
         %CollectionFormField{} = collection_form_field <-
           CollectionForms.create_collection_form_field(c_form_id, params) do
      render(conn, "create.json", collection_form_field: collection_form_field)
    end
  end

  operation(:update,
    summary: "Update a Collection Form fields",
    description: "API to update a collection form fields",
    parameters: [
      c_form_id: [in: :path, type: :string, description: "Collection Form ID", required: true],
      id: [in: :path, type: :string, description: "collection form field id", required: true]
    ],
    request_body:
      {"Collection Form field to be updated", "application/json",
       CollectionFormFieldSchema.CollectionFormFieldRequest},
    responses: [
      ok: {"Ok", "application/json", CollectionFormFieldSchema.CollectionFormFieldShow},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with %CollectionFormField{} = collection_form_field <-
           CollectionForms.get_collection_form_field(conn.assigns.current_user, id),
         %CollectionFormField{} = collection_form_field <-
           CollectionForms.update_collection_form_field(collection_form_field, params) do
      render(conn, "create.json", collection_form_field: collection_form_field)
    end
  end

  operation(:delete,
    summary: "Delete a Collection Form Field",
    description: "API to delete a collection form field",
    parameters: [
      c_form_id: [in: :path, type: :string, description: "Collection Form ID", required: true],
      id: [in: :path, type: :string, description: "collection form field id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", CollectionFormFieldSchema.CollectionFormFieldShow},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %CollectionFormField{} = collection_form_field <-
           CollectionForms.get_collection_form_field(conn.assigns.current_user, id),
         {:ok, collection_form_field} <-
           CollectionForms.delete_collection_form_field(collection_form_field) do
      render(conn, "create.json", collection_form_field: collection_form_field)
    end
  end
end
