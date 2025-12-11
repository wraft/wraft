defmodule WraftDocWeb.Api.V1.BlockTemplateController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "block_template:manage",
    index: "block_template:show",
    show: "block_template:show",
    update: "block_template:manage",
    delete: "block_template:delete",
    bulk_import: "block_template:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.BlockTemplates
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.DataTemplates
  alias WraftDocWeb.Schemas.BlockTemplate, as: BlockTemplateSchema
  alias WraftDocWeb.Schemas.Error

  tags(["BlockTemplates"])

  operation(:create,
    summary: "Create block_template",
    description: "Create block_template API",
    request_body:
      {"BlockTemplate to be created", "application/json",
       BlockTemplateSchema.BlockTemplateRequest},
    responses: [
      ok: {"Ok", "application/json", BlockTemplateSchema.BlockTemplate},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %BlockTemplate{} = block_template <-
           BlockTemplates.create_block_template(current_user, params) do
      render(conn, "block_template.json", block_template: block_template)
    end
  end

  operation(:index,
    summary: "BlockTemplate index",
    description: "API to get the list of all block_templates created so far",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", BlockTemplateSchema.BlockTemplateIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: block_templates,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- BlockTemplates.index_block_template(current_user, params) do
      render(conn, "index.json",
        block_templates: block_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a block_template",
    description: "API to show details of a block_template",
    parameters: [
      id: [in: :path, type: :string, description: "block_template id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", BlockTemplateSchema.BlockTemplate},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %BlockTemplate{} = block_template <- BlockTemplates.get_block_template(id, current_user) do
      render(conn, "block_template.json", block_template: block_template)
    end
  end

  operation(:update,
    summary: "Update a block_template",
    description: "API to update a block_template",
    parameters: [
      id: [in: :path, type: :string, description: "block_template id", required: true]
    ],
    request_body:
      {"BlockTemplate to be updated", "application/json",
       BlockTemplateSchema.BlockTemplateRequest},
    responses: [
      ok: {"Ok", "application/json", BlockTemplateSchema.BlockTemplate},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %BlockTemplate{} = block_template <- BlockTemplates.get_block_template(id, current_user),
         %BlockTemplate{} = block_template <-
           BlockTemplates.update_block_template(block_template, params) do
      render(conn, "block_template.json", block_template: block_template)
    end
  end

  operation(:delete,
    summary: "Delete a block_template",
    description: "API to delete a block_template",
    parameters: [
      id: [in: :path, type: :string, description: "block_template id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", BlockTemplateSchema.BlockTemplate},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %BlockTemplate{} = block_template <- BlockTemplates.get_block_template(id, current_user),
         {:ok, %BlockTemplate{}} <- BlockTemplates.delete_block_template(block_template) do
      render(conn, "block_template.json", block_template: block_template)
    end
  end

  operation(:bulk_import,
    summary: "Create block template in bulk",
    description: "API for block template bulk creation",
    request_body:
      {"Bulk block template creation source file and mapping", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Bulk block template creation source file"
           },
           mapping: %OpenApiSpex.Schema{type: :string, description: "Mappings for the CSV"}
         }
       }},
    responses: [
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec bulk_import(Plug.Conn.t(), map) :: Plug.Conn.t()
  def bulk_import(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Oban.Job{}} <-
           DataTemplates.insert_block_template_bulk_import_work(
             current_user,
             params["mapping"],
             params["file"]
           ) do
      conn
      |> put_view(WraftDocWeb.Api.V1.DataTemplateView)
      |> render("bulk.json", resource: "Block Template")
    end
  end
end
