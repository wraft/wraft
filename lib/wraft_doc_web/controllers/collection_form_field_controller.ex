defmodule WraftDocWeb.Api.V1.CollectionFormFieldController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.Authorized,
    show: "collection_form_field:show",
    create: "collection_form_field:manage",
    update: "collection_form_field:manage",
    delete: "collection_form_field:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document
  alias WraftDoc.Document.CollectionForm
  alias WraftDoc.Document.CollectionFormField

  def swagger_definitions do
    %{
      CollectionFormFieldRequest:
        swagger_schema do
          # name("Collection Form Field")
          description("Collection Form Field")

          properties do
            id(:string, "The ID of the collection form field", required: true)
            name(:string, "title of the collection form field")
            description(:string, "description for collection form field")
          end

          example(%{
            name: "Collection Form Field",
            description: "collection form",
            collection_form_id: "collection form id"
          })
        end,
      CollectionFormFieldShow:
        swagger_schema do
          # name("Show collection form field")
          description("show collection form field and its details")

          properties do
            id(:string, "The ID of the collection form field", required: true)
            name(:string, "name of the collection form field")
            description(:string, "Description for name")
          end

          example(%{
            collection_form_field: %{
              id: "1232148nb3478",
              name: "Collection Form Field",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end
    }
  end

  swagger_path :show do
    get("/collection_forms/{c_form_id}/collection_fields/{id}")
    summary("Show an collection form fields")
    description("API to get all details of an collection form fields")

    parameters do
      id(:path, :string, "ID of the collection form fields", required: true)
    end

    response(200, "Ok", Schema.ref(:CollectionFormFieldShow))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def show(conn, %{"id" => collection_form_id}) do
    with %CollectionFormField{} = collection_form_field <-
           Document.get_collection_form_field(conn.assigns.current_user, collection_form_id) do
      render(conn, "show.json", collection_form_field: collection_form_field)
    end
  end

  swagger_path :create do
    post("/collection_forms/{c_form_id}/collection_fields")
    summary("Create an collection form fields api")
    description("Create an collection form fields api")
    operation_id("create_collection_forms_fields")

    parameters do
      collection_form_field(
        :body,
        Schema.ref(:CollectionFormFieldRequest),
        "Collection Form Field to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:CollectionFormFieldShow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, %{"c_form_id" => c_form_id} = params) do
    with %CollectionForm{} <- Document.get_collection_form(conn.assigns.current_user, c_form_id),
         %CollectionFormField{} = collection_form_field <-
           Document.create_collection_form_field(c_form_id, params) do
      render(conn, "create.json", collection_form_field: collection_form_field)
    end
  end

  swagger_path :update do
    put("/collection_forms/{c_form_id}/collection_fields/{id}")
    summary("Update a Collection Form fields")
    description("API to update a collection form fields")

    parameters do
      id(:path, :string, "collection form field id", required: true)

      collection_form(
        :body,
        Schema.ref(:CollectionFormFieldRequest),
        "Collection Form field to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:CollectionFormShow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def update(conn, %{"id" => id} = params) do
    with %CollectionFormField{} = collection_form_field <-
           Document.get_collection_form_field(conn.assigns.current_user, id),
         %CollectionFormField{} = collection_form_field <-
           Document.update_collection_form_field(collection_form_field, params) do
      render(conn, "create.json", collection_form_field: collection_form_field)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/collection_forms/{c_form_id}/collection_fields/{id}")
    summary("Delete a Collection Form Field")
    description("API to delete a collection form field")

    parameters do
      id(:path, :string, "collection form field id", required: true)
    end

    response(200, "Ok", Schema.ref(:CollectionFormFieldShow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => id}) do
    with %CollectionFormField{} = collection_form_field <-
           Document.get_collection_form_field(conn.assigns.current_user, id),
         {:ok, collection_form_field} <-
           Document.delete_collection_form_field(collection_form_field) do
      render(conn, "create.json", collection_form_field: collection_form_field)
    end
  end
end
