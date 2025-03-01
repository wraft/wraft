defmodule WraftDocWeb.Api.V1.CollectionFormController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.Authorized,
    show: "collection_form:show",
    create: "collection_form:manage",
    update: "collection_form:manage",
    delete: "collection_form:delete",
    index: "collection_form:show"

  alias WraftDoc.Documents
  alias WraftDoc.Documents.CollectionForm

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      CollectionFormRequest:
        swagger_schema do
          title("Collection Form")
          description("Collection Form")

          properties do
            title(:string, "title of the collection form")
            description(:string, "description for collection form")
            fields(:array, "Form fields")
          end

          example(%{
            title: "Collection Form",
            description: "collection form",
            fields: [
              %{name: "Title", meta: %{color: "black"}, field_type: "string"}
            ]
          })
        end,
      CollectionFormShow:
        swagger_schema do
          title("Show collection form")
          description("show collection form and its details")

          properties do
            id(:string, "The ID of the collection form", required: true)
            title(:string, "title of the collection form")
            description(:string, "Description for title")
          end

          example(%{
            collection_form: %{
              id: "1232148nb3478",
              title: "Collection Form",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      CollectionFormIndex:
        swagger_schema do
          properties do
            collection_forms(Schema.ref(:CollectionFormShow))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            collection_forms: [
              %{
                collection_form: %{
                  description: "collection form",
                  id: "6006ce53-edf0-4044-8288-0422ef9ca2d8",
                  inserted_at: "2020-01-21T14:00:00Z",
                  title: "Collection Form",
                  updated_at: "2020-02-21T14:00:00Z"
                }
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end
    }
  end

  swagger_path :show do
    get("/collection_forms/{id}")
    summary("Show an collection form")
    description("API to get all details of an collection form")

    parameters do
      id(:path, :string, "ID of the collection form", required: true)
    end

    response(200, "Ok", Schema.ref(:CollectionFormShow))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def show(conn, %{"id" => collection_form_id}) do
    with %CollectionForm{} = collection_form <-
           Documents.get_collection_form(conn.assigns.current_user, collection_form_id) do
      render(conn, "show.json", collection_form: collection_form)
    end
  end

  swagger_path :create do
    post("/collection_forms")
    summary("Create an collection form api")
    description("Create an collection form api")
    operation_id("create_collection_forms")

    parameters do
      collection_form(:body, Schema.ref(:CollectionFormRequest), "Collection Form to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:CollectionFormShow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, params) do
    with %CollectionForm{} = collection_form <-
           Documents.create_collection_form(conn.assigns.current_user, params) do
      render(conn, "create.json", collection_form: collection_form)
    end
  end

  swagger_path :update do
    put("/collection_forms/{id}")
    summary("Update a Collection Form")
    description("API to update a collection form")

    parameters do
      id(:path, :string, "collection form id", required: true)

      collection_form(:body, Schema.ref(:CollectionFormRequest), "Collection Form to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:CollectionFormShow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def update(conn, %{"id" => id} = params) do
    with %CollectionForm{} = collection_form <-
           Documents.get_collection_form(conn.assigns.current_user, id),
         %CollectionForm{} = collection_form <-
           Documents.update_collection_form(collection_form, params) do
      render(conn, "create.json", collection_form: collection_form)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/collection_forms/{id}")
    summary("Delete a Collection Form")
    description("API to delete a collection form")

    parameters do
      id(:path, :string, "collection form id", required: true)
    end

    response(200, "Ok", Schema.ref(:CollectionFormShow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => id}) do
    with %CollectionForm{} = collection_form <-
           Documents.get_collection_form(conn.assigns.current_user, id),
         {:ok, collection_form} <- Documents.delete_collection_form(collection_form) do
      render(conn, "collection_form.json", collection_form: collection_form)
    end
  end

  swagger_path :index do
    get("/collection_forms")
    summary("show all the collection forms")
    description("API to show all the collection forms with preloaded collection form fields")

    parameters do
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:CollectionFormIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def index(conn, params) do
    with %{
           entries: collection_forms,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.list_collection_form(conn.assigns.current_user, params) do
      render(conn, "index.json",
        collection_forms: collection_forms,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
