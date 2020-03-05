defmodule WraftDocWeb.Api.V1.ThemeController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Theme}

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
          items(Schema.ref(:Theme))
        end
    }
  end

  @doc """
  Create a layout.
  """
  swagger_path :create do
    post("/themes")
    summary("Create theme")
    description("Create theme API")

    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Theme's name", required: true)

    parameter(:font, :formData, :string, "Font to be used in the theme", required: true)

    parameter(:typescale, :formData, :string, "Typescale of the theme", required: true)

    parameter(:file, :formData, :file, "Theme file to upload")

    response(200, "Ok", Schema.ref(:Theme))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Theme{} = theme} <- Document.create_theme(current_user, params) do
      conn
      |> render("create.json", theme: theme)
    end
  end

  @doc """
  Index of themes in the current user's organisation.
  """
  swagger_path :index do
    get("/themes")
    summary("Theme index")
    description("Theme index API")

    response(200, "Ok", Schema.ref(:Themes))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns[:current_user]

    themes = Document.theme_index(current_user)

    conn
    |> render("index.json", themes: themes)
  end
end
