defmodule WraftDocWeb.Api.V1.LayoutController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "layout:create",
    index: "layout:show",
    show: "layout:show",
    update: "layout:manage",
    delete: "layout:delete",
    delete_layout_asset: "layout:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents.Engine
  alias WraftDoc.Frames
  alias WraftDoc.Layouts
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Layout, as: LayoutSchema

  tags(["Layouts"])

  operation(:create,
    summary: "Create Layout",
    description: "Creates a new asset and uses it to create a layout",
    request_body:
      {"Layout creation params", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           asset_name: %OpenApiSpex.Schema{type: :string, description: "Name of the asset"},
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Asset file to upload"
           },
           type: %OpenApiSpex.Schema{type: :string, description: "Type of the asset"},
           name: %OpenApiSpex.Schema{type: :string, description: "Layout's name"},
           description: %OpenApiSpex.Schema{type: :string, description: "Layout description"},
           width: %OpenApiSpex.Schema{type: :string, description: "Layout width"},
           height: %OpenApiSpex.Schema{type: :string, description: "Layout height"},
           unit: %OpenApiSpex.Schema{type: :string, description: "Layout dimension unit"},
           slug: %OpenApiSpex.Schema{type: :string, description: "Name of slug to be used"},
           frame_id: %OpenApiSpex.Schema{type: :string, description: "ID of the frame"},
           screenshot: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Screenshot to upload"
           },
           engine_id: %OpenApiSpex.Schema{type: :string, description: "ID of layout's engine"}
         },
         required: [
           :asset_name,
           :file,
           :type,
           :name,
           :description,
           :width,
           :height,
           :unit,
           :screenshot,
           :engine_id
         ]
       }},
    responses: [
      ok: {"Ok", "application/json", LayoutSchema.LayoutAndEngine},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Engine{} = engine <- Frames.get_engine_by_frame_type(params),
         {:ok, %{layout: layout}} <- Layouts.create_layout(current_user, engine, params) do
      Typesense.create_document(layout)
      render(conn, "create.json", doc_layout: layout)
    end
  end

  operation(:index,
    summary: "Layout index",
    description: "API to get the list of all layouts created so far",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Layout Name"],
      sort: [
        in: :query,
        type: :string,
        description: "Sort Keys => name, name_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", LayoutSchema.LayoutIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: layouts,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Layouts.layout_index(current_user, params) do
      render(conn, "index.json",
        doc_layouts: layouts,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a Layout",
    description: "API to show details of a layout",
    parameters: [
      id: [in: :path, type: :string, description: "layout id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", LayoutSchema.ShowLayout},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Layout{} = layout <- Layouts.show_layout(id, current_user) do
      render(conn, "show.json", doc_layout: layout)
    end
  end

  operation(:update,
    summary: "Update a Layout",
    description: "API to update a layout",
    parameters: [
      id: [in: :path, type: :string, description: "layout id", required: true]
    ],
    request_body:
      {"Layout update params", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           asset_id: %OpenApiSpex.Schema{type: :string, description: "asset id"},
           asset_name: %OpenApiSpex.Schema{type: :string, description: "Name of the asset"},
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Asset file to upload"
           },
           type: %OpenApiSpex.Schema{type: :string, description: "Type of the asset"},
           name: %OpenApiSpex.Schema{type: :string, description: "Layout's name"},
           description: %OpenApiSpex.Schema{type: :string, description: "Layout description"},
           width: %OpenApiSpex.Schema{type: :string, description: "Layout width"},
           height: %OpenApiSpex.Schema{type: :string, description: "Layout height"},
           unit: %OpenApiSpex.Schema{type: :string, description: "Layout dimension unit"},
           slug: %OpenApiSpex.Schema{type: :string, description: "Name of slug to be used"},
           frame_id: %OpenApiSpex.Schema{type: :string, description: "ID of the frame"},
           screenshot: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Screenshot to upload"
           },
           engine_id: %OpenApiSpex.Schema{type: :string, description: "ID of layout's engine"}
         },
         required: [
           :asset_id,
           :asset_name,
           :file,
           :type,
           :name,
           :description,
           :width,
           :height,
           :unit,
           :screenshot,
           :engine_id
         ]
       }},
    responses: [
      ok: {"Ok", "application/json", LayoutSchema.ShowLayout},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => layout_id} = params) do
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Layouts.get_layout(layout_id, current_user),
         %Engine{id: engine_id} = _engine <- Frames.get_engine_by_frame_type(params),
         %Layout{} = layout <-
           Layouts.update_layout(
             current_user,
             layout,
             Map.merge(params, %{"engine_id" => engine_id})
           ) do
      Typesense.update_document(layout)
      render(conn, "show.json", doc_layout: layout)
    end
  end

  operation(:delete,
    summary: "Delete a Layout",
    description: "API to delete a layout",
    parameters: [
      id: [in: :path, type: :string, description: "layout id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", LayoutSchema.Layout},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Layouts.get_layout(id, current_user),
         {:ok, %Layout{}} <- Layouts.delete_layout(layout) do
      Typesense.delete_document(layout.id, "layout")
      render(conn, "layout.json", doc_layout: layout)
    end
  end

  operation(:delete_layout_asset,
    summary: "Delete a Layout Asset",
    description: "API to delete a layout-asset association",
    parameters: [
      id: [in: :path, type: :string, description: "layout id", required: true],
      a_id: [in: :path, type: :string, description: "asset id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", LayoutSchema.ShowLayout},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec delete_layout_asset(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete_layout_asset(conn, %{"id" => l_id, "a_id" => a_id}) do
    current_user = conn.assigns[:current_user]

    with %LayoutAsset{} = layout_asset <- Layouts.get_layout_asset(l_id, a_id),
         {:ok, %LayoutAsset{}} <- Layouts.delete_layout_asset(layout_asset),
         %Layout{} = layout <- Layouts.show_layout(l_id, current_user) do
      render(conn, "show.json", doc_layout: layout)
    end
  end
end
