defmodule WraftDocWeb.Api.V1.DataTemplateController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.ContentType, Document.DataTemplate}

  def swagger_definitions do
    %{
      DataTemplateRequest:
        swagger_schema do
          title("Data template Request")
          description("Create data template request.")

          properties do
            tag(:string, "Data templates's tag", required: true)
            data(:string, "Data template's contents", required: true)
          end

          example(%{
            tag: "Main template",
            data: "Hi [user]"
          })
        end,
      DataTemplate:
        swagger_schema do
          title("Data Template")
          description("A Data Template")

          properties do
            id(:string, "The ID of the data template", required: true)
            tag(:string, "Tag name of the data template", required: true)
            data(:string, "Data template's contents")
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            tag: "Main template",
            data: "Hi [user]",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ShowDataTemplate:
        swagger_schema do
          title("Data template and all its details")
          description("API to show a data template and all its details")

          properties do
            data_template(Schema.ref(:LayoutAndEngine))
            creator(Schema.ref(:User))
            content_type(Schema.ref(:ContentType))
          end

          example(%{
            data_template: %{
              id: "1232148nb3478",
              tag: "Main tag",
              data: "Hi [user]",
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
              fields: %{
                name: "string",
                position: "string",
                joining_date: "date",
                approved_by: "string"
              },
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
  def create(conn, %{"c_type_id" => c_type_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = c_type <- Document.get_content_type(c_type_uuid),
         {:ok, %DataTemplate{} = d_template} <-
           Document.create_data_template(current_user, c_type, params) do
      conn
      |> render("create.json", d_template: d_template)
    end
  end

  @doc """
  Layout index.
  """
  swagger_path :index do
    get("/content_types/{c_type_id}/data_templates")
    summary("Data template index")
    description("API to get the list of all data templates created so far under a content type")

    parameters do
      c_type_id(:path, :string, "ID of the content type", required: true)
    end

    response(200, "Ok", Schema.ref(:DataTemplates))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"c_type_id" => c_type_uuid}) do
    data_templates = Document.data_type_index(c_type_uuid)

    conn
    |> render("index.json", data_templates: data_templates)
  end
end
