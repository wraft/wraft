defmodule WraftDocWeb.Api.V1.DataTemplateController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "data_template:manage",
    index: "data_template:show",
    all_templates: "data_template:show",
    show: "data_template:show",
    update: "data_template:manage",
    delete: "data_template:delete",
    bulk_import: "data_template:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document
  alias WraftDoc.Document.ContentType
  alias WraftDoc.Document.DataTemplate

  def swagger_definitions do
    %{
      DataTemplateRequest:
        swagger_schema do
          title("Data template Request")
          description("Create data template request.")

          properties do
            title(:string, "Data template's title", required: true)
            title_template(:string, "Title template", required: true)
            data(:string, "Data template's contents", required: true)
            serialized(:map, "Serialized data", required: true)
          end

          example(%{
            title: "Template 1",
            title_template: "Letter for [user]",
            data: "Hi [user]",
            serialized: %{title: "Offer letter of [client]", data: "Hi [user]"}
          })
        end,
      DataTemplate:
        swagger_schema do
          title("Data Template")
          description("A Data Template")

          properties do
            id(:string, "The ID of the data template", required: true)
            title(:string, "Title of the data template", required: true)
            title_template(:string, "Title content of the data template", required: true)
            data(:string, "Data template's contents")
            serialized(:map, "Serialized data")
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            title: "Template 1",
            title_template: "Letter for [user]",
            data: "Hi [user]",
            serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      DataTemplateAndContentType:
        swagger_schema do
          title("Data Template and its content type")
          description("A Data Template and its content type")

          properties do
            id(:string, "The ID of the data template", required: true)
            title(:string, "Title of the data template", required: true)
            title_template(:string, "Title content of the data template", required: true)
            data(:string, "Data template's contents")
            serialized(:map, "Serialized data")
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
            content_type(Schema.ref(:ContentTypeWithoutFields))
          end

          example(%{
            id: "1232148nb3478",
            title: "Template 1",
            title_template: "Letter for [user]",
            data: "Hi [user]",
            serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              prefix: "OFFLET",
              color: "#fffff",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ShowDataTemplate:
        swagger_schema do
          title("Data template and all its details")
          description("API to show a data template and all its details")

          properties do
            data_template(Schema.ref(:LayoutAndEngine))
            creator(Schema.ref(:User))
            content_type(Schema.ref(:ContentTypeWithoutFields))
          end

          example(%{
            data_template: %{
              id: "1232148nb3478",
              title: "Main Template",
              title_template: "Letter for [user]",
              data: "Hi [user]",
              serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              prefix: "OFFLET",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      DataTemplates:
        swagger_schema do
          title("Data templates under a content type")
          description("All data template that have been created under a content type")
          type(:array)
          items(Schema.ref(:DataTemplate))
        end,
      DataTemplatesIndex:
        swagger_schema do
          properties do
            data_templates(Schema.ref(:DataTemplateAndContentType))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            data_templates: [
              %{
                id: "1232148nb3478",
                title: "Main template",
                title_template: "Letter for [user]",
                data: "Hi [user]",
                serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z",
                content_type: %{
                  id: "1232148nb3478",
                  name: "Offer letter",
                  description: "An offer letter",
                  prefix: "OFFLET",
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
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

  @doc """
  Create a data template.
  """
  swagger_path :create do
    post("/content_types/{c_type_id}/data_templates")
    summary("Create data template")
    description("Create data template API")

    parameters do
      c_type_id(:path, :string, "ID of the content type", required: true)

      data_template(:body, Schema.ref(:DataTemplateRequest), "Data template to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:DataTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"c_type_id" => c_type_id} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = c_type <- Document.get_content_type(current_user, c_type_id),
         {:ok, %DataTemplate{} = d_template} <-
           Document.create_data_template(current_user, c_type, params) do
      render(conn, "create.json", d_template: d_template)
    end
  end

  @doc """
  Data template index.
  """
  swagger_path :index do
    get("/content_types/{c_type_id}/data_templates")
    summary("Data template index")
    description("API to get the list of all data templates created so far under a content type")

    parameters do
      c_type_id(:path, :string, "ID of the content type", required: true)
      page(:query, :string, "Page number")
      title(:query, :string, "Title")

      sort(
        :query,
        :string,
        "sort keys => updated_at, updated_at_desc, inserted_at, inserted_at_desc"
      )
    end

    response(200, "Ok", Schema.ref(:DataTemplatesIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"c_type_id" => c_type_id} = params) do
    with %{
           entries: data_templates,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.data_template_index(c_type_id, params) do
      render(conn, "index.json",
        data_templates: data_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  All Data templates.
  """
  swagger_path :all_templates do
    get("/data_templates")
    summary("All Data templates")
    description("API to get the list of all data templates created so far under an organisation")
    parameter(:page, :query, :string, "Page number")
    parameter(:title, :query, :string, "Title")
    response(200, "Ok", Schema.ref(:DataTemplatesIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec all_templates(Plug.Conn.t(), map) :: Plug.Conn.t()
  def all_templates(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: data_templates,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.data_templates_index_of_an_organisation(current_user, params) do
      render(conn, "index.json",
        data_templates: data_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show data template.
  """
  # TODO update the swagger docs for data template show to add fields as well
  swagger_path :show do
    get("/data_templates/{id}")
    summary("Show Data template")
    description("API to get all details of a data template")

    parameters do
      id(:path, :string, "ID of the data template", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowDataTemplate))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => d_temp_id}) do
    current_user = conn.assigns[:current_user]

    with %DataTemplate{} = data_template <- Document.show_d_template(current_user, d_temp_id) do
      render(conn, "show.json", d_template: data_template)
    end
  end

  @doc """
  Update a data template.
  """
  swagger_path :update do
    put("/data_templates/{id}")
    summary("Update a data template")
    description("API to update a data template")

    parameters do
      id(:path, :string, "Data template id", required: true)

      data_templte(:body, Schema.ref(:DataTemplateRequest), "Data template to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:ShowDataTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %DataTemplate{} = d_temp <- Document.get_d_template(current_user, id),
         %DataTemplate{} = d_temp <- Document.update_data_template(d_temp, params) do
      render(conn, "show.json", d_template: d_temp)
    end
  end

  @doc """
  Delete a Data template.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/data_templates/{id}")
    summary("Delete a data template")
    description("API to delete a data template")

    parameters do
      id(:path, :string, "data template id", required: true)
    end

    response(200, "Ok", Schema.ref(:DataTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %DataTemplate{} = d_temp <- Document.get_d_template(current_user, id),
         {:ok, %DataTemplate{}} <- Document.delete_data_template(d_temp) do
      render(conn, "create.json", d_template: d_temp)
    end
  end

  @doc """
  Bulk data template creation.
  """
  swagger_path :bulk_import do
    post("/content_types/{c_type_id}/data_templates/bulk_import")
    summary("Create data template in bulk")
    description("API for data template bulk creation")
    consumes("multipart/form-data")

    parameter(:c_type_id, :path, :string, "Content type id", required: true)
    parameter(:file, :formData, :file, "Bulk data template creation source file")
    parameter(:mapping, :formData, :map, "Mappings for the CSV")

    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec bulk_import(Plug.Conn.t(), map) :: Plug.Conn.t()
  def bulk_import(
        conn,
        %{"c_type_id" => c_type_id} = params
      ) do
    user = conn.assigns[:current_user]

    with %ContentType{} <- Document.get_content_type(user, c_type_id),
         {:ok, %Oban.Job{}} <-
           Document.insert_data_template_bulk_import_work(
             user.id,
             c_type_id,
             params["mapping"],
             params["file"]
           ) do
      render(conn, "bulk.json", resource: "Data Template")
    end
  end
end
