defmodule WraftDocWeb.Api.V1.BlockTemplateController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.BlockTemplate}

  def swagger_definitions do
    %{
      BlockTemplateRequest:
        swagger_schema do
          title("BlockTemplate Request")
          description("Create block_template request.")

          properties do
            title(:string, "The Title of the title", required: true)
            body(:string, "The Body of the body", required: true)
            serialised(:string, "The Serialised of the serialised", required: true)
          end

          example(%{
            title: "a sample title",
            body: "a sample body",
            serialised: "a sample serialised"
          })
        end,
      BlockTemplate:
        swagger_schema do
          title("BlockTemplate")
          description("A BlockTemplate")

          properties do
            title(:string, "The Title of the title", required: true)
            body(:string, "The Body of the body", required: true)
            serialised(:string, "The Serialised of the serialised", required: true)

            inserted_at(:string, "When was the block_template inserted", format: "ISO-8601")
            updated_at(:string, "When was the block_template last updated", format: "ISO-8601")
          end

          example(%{
            title: "a sample title",
            body: "a sample body",
            serialised: "a sample serialised",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      BlockTemplates:
        swagger_schema do
          title("BlockTemplate list")
          type(:array)
          items(Schema.ref(:BlockTemplate))
        end,
      BlockTemplateIndex:
        swagger_schema do
          properties do
            block_templates(Schema.ref(:BlockTemplates))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            block_templates: [
              %{
                title: "a sample title",
                body: "a sample body",
                serialised: "a sample serialised"
              },
              %{
                title: "a sample title",
                body: "a sample body",
                serialised: "a sample serialised"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end
    }
  end

  swagger_path :create do
    post("/block_templates")
    summary("Create block_template")
    description("Create block_template API")

    parameters do
      block_template(:body, Schema.ref(:BlockTemplateRequest), "BlockTemplate to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:BlockTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %BlockTemplate{} = block_template <- Document.create_block_template(current_user, params) do
      conn |> render("block_template.json", block_template: block_template)
    end
  end

  swagger_path :index do
    get("/block_templates")
    summary("BlockTemplate index")
    description("API to get the list of all block_templates created so far")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:BlockTemplateIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: block_templates,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.block_template_index(current_user, params) do
      conn
      |> render("index.json",
        block_templates: block_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :show do
    get("/block_templates/{id}")
    summary("Show a block_template")
    description("API to show details of a block_template")

    parameters do
      id(:path, :string, "block_template id", required: true)
    end

    response(200, "Ok", Schema.ref(:BlockTemplate))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => uuid}) do
    with %BlockTemplate{} = block_template <- Document.get_block_template(uuid) do
      conn
      |> render("block_template.json", block_template: block_template)
    end
  end

  swagger_path :update do
    put("/block_templates/{id}")
    summary("Update a block_template")
    description("API to update a block_template")

    parameters do
      id(:path, :string, "block_template id", required: true)

      block_template(:body, Schema.ref(:BlockTemplateRequest), "BlockTemplate to be updated",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:BlockTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %BlockTemplate{} = block_template <- Document.get_block_template(uuid),
         %BlockTemplate{} = block_template <-
           Document.update_block_template(current_user, block_template, params) do
      conn
      |> render("block_template.json", block_template: block_template)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/block_templates/{id}")
    summary("Delete a block_template")
    description("API to delete a block_template")

    parameters do
      id(:path, :string, "block_template id", required: true)
    end

    response(200, "Ok", Schema.ref(:BlockTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %BlockTemplate{} = block_template <- Document.get_block_template(uuid),
         {:ok, %BlockTemplate{}} <- Document.delete_block_template(current_user, block_template) do
      conn
      |> render("block_template.json", block_template: block_template)
    end
  end
end