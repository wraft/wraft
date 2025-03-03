defmodule WraftDocWeb.Api.V1.ThemeController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

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

  def swagger_definitions do
    %{
      Theme:
        swagger_schema do
          title("Theme")
          description("A Theme")

          properties do
            id(:string, "The ID of the theme", required: true)
            name(:string, "Theme's name", required: true)
            font(:string, "Font name", required: true)
            typescale(:map, "Typescale of the theme", required: true)
            file(:string, "Theme file attachment")
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Official Letter Theme",
            font: "Malery",
            typescale: %{h1: "10", p: "6", h2: "8"},
            file: "/malory.css",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            assets: [
              "89face43-c408-4002-af3a-e8b2946f800a",
              "c70c6c80-d3ba-468c-9546-a338b0cf8d1c"
            ]
          })
        end,
      UpdateTheme:
        swagger_schema do
          title("Theme")
          description("A Theme")

          properties do
            id(:string, "The ID of the theme", required: true)
            name(:string, "Theme's name", required: true)
            font(:string, "Font name", required: true)
            typescale(:map, "Typescale of the theme", required: true)
            file(:string, "Theme file attachment")
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Official Letter Theme",
            font: "Malery",
            typescale: %{h1: "10", p: "6", h2: "8"},
            file: "/malory.css",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      Themes:
        swagger_schema do
          title("All themes and its details")

          description(
            "All themes that have been created under current user's organisation and their details"
          )

          type(:array)
          items(Schema.ref(:UpdateTheme))
        end,
      ShowTheme:
        swagger_schema do
          title("Show Theme")
          description("Show details of a theme")

          properties do
            theme(Schema.ref(:Theme))
            creator(Schema.ref(:User))
          end

          example(%{
            theme: %{
              id: "1232148nb3478",
              name: "Official Letter Theme",
              font: "Malery",
              typescale: %{h1: "10", p: "6", h2: "8"},
              file: "/malory.css",
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
            }
          })
        end,
      ThemeIndex:
        swagger_schema do
          properties do
            themes(Schema.ref(:Themes))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            themes: [
              %{
                id: "1232148nb3478",
                name: "Official Letter Theme",
                font: "Malery",
                typescale: %{h1: "10", p: "6", h2: "8"},
                file: "/malory.css",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
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
  Create a theme.
  """
  swagger_path :create do
    post("/themes")
    summary("Create theme")
    description("Create theme API")

    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Theme's name", required: true)

    parameter(:font, :formData, :string, "Font to be used in the theme, e.g. 'Malery', 'Roboto'")

    parameter(
      :body_color,
      :formData,
      :string,
      "Body color to be used in the theme, e.g. #ca1331"
    )

    parameter(
      :primary_color,
      :formData,
      :string,
      "Primary color to be used in the theme, e.g. #ca1331"
    )

    parameter(
      :secondary_color,
      :formData,
      :string,
      "Secondary color to be used in the theme, e.g #af0903"
    )

    parameter(
      :typescale,
      :formData,
      :map,
      "Typescale of the theme, e.g. {'h1': 10, 'p': 6, 'h2': 8}"
    )

    parameter(
      :assets,
      :formData,
      :list,
      "IDs of assets of the layout, eg: 8851a14a-dfe2-4579-8bdc-e3499fc150fd,8d341b6f-b15d-4773-a99b-da9493ffd763"
    )

    parameter(:preview_file, :formData, :file, "Preview file to upload, e.g. .png .jpg")

    response(200, "Ok", Schema.ref(:Theme))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Theme{} = theme <- Themes.create_theme(current_user, params) do
      Typesense.create_document(theme)
      render(conn, "create.json", theme: theme)
    end
  end

  @doc """
  Index of themes in the current user's organisation.
  """
  swagger_path :index do
    get("/themes")
    summary("Theme index")
    description("Theme index API")

    parameter(:page, :query, :string, "Page number")
    parameter(:name, :query, :string, "Theme Name")

    parameter(
      :sort,
      :query,
      :string,
      "Sort Keys => name, name_desc, inserted_at, inserted_at_desc"
    )

    response(200, "Ok", Schema.ref(:ThemeIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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

  @doc """
  Show a theme.
  """
  swagger_path :show do
    get("/themes/{id}")
    summary("Show a theme")
    description("Show a theme API")

    parameters do
      id(:path, :string, "theme id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowTheme))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => theme_uuid}) do
    current_user = conn.assigns.current_user

    with %Theme{} = theme <- Themes.show_theme(theme_uuid, current_user) do
      render(conn, "show.json", theme: theme)
    end
  end

  @doc """
  Update a theme.
  """
  swagger_path :update do
    put("/themes/{id}")
    summary("Update a theme")
    description("Update a theme API")
    consumes("multipart/form-data")
    parameter(:id, :path, :string, "theme id", required: true)
    parameter(:name, :formData, :string, "Theme's name", required: true)

    parameter(:font, :formData, :string, "Font to be used in the theme", required: true)

    parameter(:typescale, :formData, :string, "Typescale of the theme")

    parameter(:preview_file, :formData, :file, "Theme preview file to upload")

    parameter(:assets, :formData, :list, "IDs of assets of the layout")

    response(200, "Ok", Schema.ref(:UpdateTheme))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => theme_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Theme{} = theme <- Themes.get_theme(theme_uuid, current_user),
         %Theme{} = theme <- Themes.update_theme(theme, current_user, params) do
      Typesense.update_document(theme)
      render(conn, "create.json", theme: theme)
    end
  end

  @doc """
  Delete a Theme.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/themes/{id}")
    summary("Delete a theme")
    description("API to delete a theme")

    parameters do
      id(:path, :string, "theme id", required: true)
    end

    response(200, "Ok", Schema.ref(:UpdateTheme))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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
