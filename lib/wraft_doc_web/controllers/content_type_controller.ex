defmodule WraftDocWeb.Api.V1.ContentTypeController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "variant:manage",
    index: "variant:show",
    show: "variant:show",
    update: "variant:manage",
    delete: "variant:delete",
    show_content_type_role: "variant:show",
    search: "variant:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Documents
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Layouts
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDoc.Themes
  alias WraftDoc.Themes.Theme
  alias WraftDocWeb.Schemas.ContentType, as: ContentTypeSchema
  alias WraftDocWeb.Schemas.Error

  tags(["content_types"])

  operation(:create,
    summary: "Create content type",
    description: "Create content type API",
    parameters: [],
    request_body:
      {"Content Type to be created", "application/json", ContentTypeSchema.ContentTypeRequest},
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ContentTypeAndLayoutAndFlowAndTheme},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(
        conn,
        %{"layout_id" => layout_id, "flow_id" => flow_id, "theme_id" => theme_id} = params
      ) do
    current_user = conn.assigns[:current_user]

    with %Layout{} <- Layouts.get_layout(layout_id, current_user),
         %Flow{} <- Enterprise.get_flow(flow_id, current_user),
         %Theme{} <- Themes.get_theme(theme_id, current_user),
         %ContentType{} = content_type <-
           ContentTypes.create_content_type(current_user, params) do
      Typesense.create_document(content_type)
      render(conn, :create, content_type: content_type)
    end
  end

  operation(:index,
    summary: "Content Type index",
    description: "API to get the list of all content types created so far",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Name"],
      prefix: [in: :query, type: :string, description: "Prefix"],
      sort: [
        in: :query,
        type: :string,
        description: "sort keys => name, name_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ContentTypesIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: content_types,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- ContentTypes.content_type_index(current_user, params) do
      render(conn, "index.json",
        content_types: content_types,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a Content Type",
    description: "API to show details of a content type",
    parameters: [
      id: [in: :path, type: :string, description: "content type id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ShowContentType},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = content_type <- ContentTypes.show_content_type(current_user, id) do
      render(conn, "show.json", content_type: content_type)
    end
  end

  operation(:update,
    summary: "Update a Content Type",
    description: "API to update a content type",
    parameters: [
      id: [in: :path, type: :string, description: "content type id", required: true]
    ],
    request_body:
      {"Content Type to be updated", "application/json", ContentTypeSchema.ContentTypeRequest},
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ShowContentType},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid, "layout_id" => layout_id} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = content_type <- ContentTypes.get_content_type(current_user, uuid),
         %Layout{} = layout <- Layouts.get_layout(layout_id, current_user),
         %ContentType{} = content_type <-
           ContentTypes.update_content_type(content_type, layout, current_user, params) do
      Typesense.update_document(content_type)
      render(conn, "show.json", content_type: content_type)
    end
  end

  operation(:delete,
    summary: "Delete a Content Type",
    description: "API to delete a content type",
    parameters: [
      id: [in: :path, type: :string, description: "content type id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ContentTypeWithoutFields},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = content_type <- ContentTypes.get_content_type(current_user, id),
         {:ok, %ContentType{}} <- ContentTypes.delete_content_type(content_type) do
      Typesense.delete_document(content_type.id, "content_type")
      render(conn, "content_type.json", content_type: content_type)
    end
  end

  operation(:bulk_build,
    summary: "Bulk build documents",
    description: "API to bulk build documents for a content type",
    parameters: [
      c_type_id: [in: :path, type: :string, description: "Content type id", required: true]
    ],
    request_body:
      {"Bulk build params", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           state_id: %OpenApiSpex.Schema{type: :string, description: "State id"},
           d_temp_id: %OpenApiSpex.Schema{type: :string, description: "Data template id"},
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Bulk build source file"
           },
           mapping: %OpenApiSpex.Schema{type: :object, description: "Mappings for the CSV"}
         },
         required: [:state_id, :d_temp_id, :file]
       }},
    responses: [
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec bulk_build(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def bulk_build(
        conn,
        %{
          "c_type_id" => c_type_id,
          "state_id" => state_id,
          "d_temp_id" => d_temp_id,
          "mapping" => mapping,
          "file" => file
        }
      ) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Oban.Job{}} <-
           Documents.insert_bulk_build_work(
             c_type_id,
             state_id,
             d_temp_id,
             file,
             mapping,
             current_user
           ) do
      render(conn, "bulk_build.json")
    end
  end

  operation(:show_content_type_role,
    summary: "Show content type role",
    description: "API to show content type role",
    parameters: [
      id: [in: :path, type: :string, description: "content type id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ContentTypeRole},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  @spec show_content_type_role(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show_content_type_role(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = content_type <- ContentTypes.show_content_type(current_user, id) do
      render(conn, "show_role.json", content_type: content_type)
    end
  end

  operation(:search,
    summary: "Search content type",
    description: "API to search content type",
    parameters: [
      q: [in: :query, type: :string, description: "Search query", required: true],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentTypeSchema.ContentTypeSearch},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec search(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def search(conn, %{"key" => key} = params) do
    with %{
           entries: content_types,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- ContentTypes.filter_content_type_title(key, params) do
      render(conn, "index.json",
        content_types: content_types,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
