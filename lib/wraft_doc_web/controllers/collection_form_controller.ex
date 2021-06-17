defmodule WraftDocWeb.Api.V1.CollectionFormController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Document
  alias WraftDoc.Document.CollectionForm
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
          end

          example(%{
            title: "Collection Form",
            description: "collection form"
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
    with %CollectionForm{} = collection_form <- Document.get_collection_form(collection_form_id) do
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
    with %CollectionForm{} = collection_form <- Document.create_collection_form(params) do
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
    with %CollectionForm{} = collection_form <- Document.get_collection_form(id),
         %CollectionForm{} = collection_form <-
           Document.update_collection_form(collection_form, params) do
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
    with %CollectionForm{} = collection_form <- Document.get_collection_form(id),
         {:ok, collection_form} <- Document.delete_collection_form(collection_form) do
      render(conn, "create.json", collection_form: collection_form)
    end
  end
end
