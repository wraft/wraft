defmodule WraftDocWeb.Api.V1.ThemeController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "theme:manage",
    index: "theme:show",
    show: "theme:show",
    update: "theme:manage",
    delete: "theme:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDoc.Themes
  alias WraftDoc.Themes.Theme
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Theme, as: ThemeSchema

  tags(["themes"])

  operation(:create,
    summary: "Create theme",
    description: "Create theme API",
    request_body:
      {"Theme creation params", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Theme's name"},
           font: %OpenApiSpex.Schema{
             type: :string,
             description: "Font to be used in the theme, e.g. 'Malery', 'Roboto'"
           },
           body_color: %OpenApiSpex.Schema{
             type: :string,
             description: "Body color to be used in the theme, e.g. #ca1331"
           },
           primary_color: %OpenApiSpex.Schema{
             type: :string,
             description: "Primary color to be used in the theme, e.g. #ca1331"
           },
           secondary_color: %OpenApiSpex.Schema{
             type: :string,
             description: "Secondary color to be used in the theme, e.g #af0903"
           },
           typescale: %OpenApiSpex.Schema{
             type: :object,
             description: "Typescale of the theme, e.g. {'h1': 10, 'p': 6, 'h2': 8}"
           },
           assets: %OpenApiSpex.Schema{
             type: :array,
             items: %OpenApiSpex.Schema{type: :string},
             description:
               "IDs of assets of the layout, eg: 8851a14a-dfe2-4579-8bdc-e3499fc150fd,8d341b6f-b15d-4773-a99b-da9493ffd763"
           },
           preview_file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Preview file to upload, e.g. .png .jpg"
           }
         },
         required: [:name]
       }},
    responses: [
      ok: {"Ok", "application/json", ThemeSchema.Theme},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Theme{} = theme <- Themes.create_theme(current_user, params) do
      Typesense.create_document(theme)
      render(conn, "create.json", theme: theme)
    end
  end

  operation(:index,
    summary: "Theme index",
    description: "Index of themes in the current user's organisation",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Theme Name"],
      sort: [
        in: :query,
        type: :string,
        description: "Sort Keys => name, name_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", ThemeSchema.ThemeIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: themes,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Themes.theme_index(current_user, params) do
      render(conn, "index.json",
        themes: themes,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a theme",
    description: "Show a theme API",
    parameters: [
      id: [in: :path, type: :string, description: "theme id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ThemeSchema.ShowTheme},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => theme_uuid}) do
    current_user = conn.assigns.current_user

    with %Theme{} = theme <- Themes.show_theme(theme_uuid, current_user) do
      render(conn, "show.json", theme: theme)
    end
  end

  operation(:update,
    summary: "Update a theme",
    description: "Update a theme API",
    parameters: [
      id: [in: :path, type: :string, description: "theme id", required: true]
    ],
    request_body:
      {"Theme update params", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Theme's name"},
           font: %OpenApiSpex.Schema{type: :string, description: "Font to be used in the theme"},
           typescale: %OpenApiSpex.Schema{type: :string, description: "Typescale of the theme"},
           preview_file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Theme preview file to upload"
           },
           assets: %OpenApiSpex.Schema{
             type: :array,
             items: %OpenApiSpex.Schema{type: :string},
             description: "IDs of assets of the layout"
           }
         },
         required: [:name, :font]
       }},
    responses: [
      ok: {"Ok", "application/json", ThemeSchema.UpdateTheme},
      not_found: {"Not found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => theme_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Theme{} = theme <- Themes.get_theme(theme_uuid, current_user),
         %Theme{} = theme <- Themes.update_theme(theme, current_user, params) do
      Typesense.update_document(theme)
      render(conn, "create.json", theme: theme)
    end
  end

  operation(:delete,
    summary: "Delete a theme",
    description: "API to delete a theme",
    parameters: [
      id: [in: :path, type: :string, description: "theme id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ThemeSchema.UpdateTheme},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %Theme{} = theme <- Themes.get_theme(uuid, current_user),
         {:ok, %Theme{}} <- Themes.delete_theme(theme) do
      Typesense.delete_document(theme.id, "theme")
      render(conn, "create.json", theme: theme)
    end
  end
end
