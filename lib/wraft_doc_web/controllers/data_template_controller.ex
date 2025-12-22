defmodule WraftDocWeb.Api.V1.DataTemplateController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "template:manage",
    index: "template:show",
    all_templates: "template:show",
    show: "template:show",
    update: "template:manage",
    delete: "template:delete",
    bulk_import: "template:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDocWeb.Schemas.DataTemplate, as: DataTemplateSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Data Templates"])

  operation(:create,
    summary: "Create data template",
    description: "Create data template API",
    parameters: [
      c_type_id: [in: :path, type: :string, description: "ID of the content type", required: true]
    ],
    request_body:
      {"Data template to be created", "application/json", DataTemplateSchema.DataTemplateRequest},
    responses: [
      ok: {"Ok", "application/json", DataTemplateSchema.DataTemplate},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"c_type_id" => c_type_id} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = c_type <- ContentTypes.get_content_type(current_user, c_type_id),
         {:ok, %DataTemplate{} = d_template} <-
           DataTemplates.create_data_template(current_user, c_type, params) do
      Typesense.create_document(d_template)
      render(conn, "create.json", d_template: d_template)
    end
  end

  operation(:index,
    summary: "Data template index",
    description: "API to get the list of all data templates created so far under a content type",
    parameters: [
      c_type_id: [in: :path, type: :string, description: "ID of the content type", required: true],
      page: [in: :query, type: :string, description: "Page number"],
      title: [in: :query, type: :string, description: "Title"],
      sort: [
        in: :query,
        type: :string,
        description: "sort keys => updated_at, updated_at_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", DataTemplateSchema.DataTemplatesIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"c_type_id" => c_type_id} = params) do
    with %{
           entries: data_templates,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- DataTemplates.data_template_index(c_type_id, params) do
      render(conn, "index.json",
        data_templates: data_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:all_templates,
    summary: "All Data templates",
    description: "API to get the list of all data templates created so far under an organisation",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      title: [in: :query, type: :string, description: "Title"]
    ],
    responses: [
      ok: {"Ok", "application/json", DataTemplateSchema.DataTemplatesIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec all_templates(Plug.Conn.t(), map) :: Plug.Conn.t()
  def all_templates(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: data_templates,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- DataTemplates.data_templates_index_of_an_organisation(current_user, params) do
      render(conn, "index.json",
        data_templates: data_templates,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show Data template",
    description: "API to get all details of a data template",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the data template", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", DataTemplateSchema.ShowDataTemplate},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => d_temp_id}) do
    current_user = conn.assigns[:current_user]

    with %DataTemplate{} = data_template <-
           DataTemplates.show_data_template(current_user, d_temp_id) do
      render(conn, "show.json", d_template: data_template)
    end
  end

  operation(:update,
    summary: "Update a data template",
    description: "API to update a data template",
    parameters: [
      id: [in: :path, type: :string, description: "Data template id", required: true]
    ],
    request_body:
      {"Data template to be updated", "application/json", DataTemplateSchema.DataTemplateRequest},
    responses: [
      ok: {"Ok", "application/json", DataTemplateSchema.ShowDataTemplate},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %DataTemplate{} = d_temp <- DataTemplates.get_data_template(current_user, id),
         %DataTemplate{} = d_temp <- DataTemplates.update_data_template(d_temp, params) do
      Typesense.update_document(d_temp)
      render(conn, "show.json", d_template: d_temp)
    end
  end

  operation(:delete,
    summary: "Delete a data template",
    description: "API to delete a data template",
    parameters: [
      id: [in: :path, type: :string, description: "data template id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", DataTemplateSchema.DataTemplate},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %DataTemplate{} = d_temp <- DataTemplates.get_data_template(current_user, id),
         {:ok, %DataTemplate{}} <- DataTemplates.delete_data_template(d_temp) do
      Typesense.delete_document(d_temp.id, "data_template")
      render(conn, "create.json", d_template: d_temp)
    end
  end

  operation(:bulk_import,
    summary: "Create data template in bulk",
    description: "API for data template bulk creation",
    parameters: [
      c_type_id: [in: :path, type: :string, description: "Content type id", required: true]
    ],
    request_body:
      {"Bulk data template creation source file", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Bulk data template creation source file"
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
  def bulk_import(
        conn,
        %{"c_type_id" => c_type_id} = params
      ) do
    user = conn.assigns[:current_user]

    with %ContentType{} <- ContentTypes.get_content_type(user, c_type_id),
         {:ok, %Oban.Job{}} <-
           DataTemplates.insert_data_template_bulk_import_work(
             user.id,
             c_type_id,
             params["mapping"],
             params["file"]
           ) do
      render(conn, "bulk.json", resource: "Data Template")
    end
  end
end
