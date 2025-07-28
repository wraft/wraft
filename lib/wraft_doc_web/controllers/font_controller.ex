defmodule WraftDocWeb.Api.V1.FontController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  # plug(WraftDocWeb.Plug.AddActionLog)

  # plug(WraftDocWeb.Plug.Authorized,
  #   create: "form:manage",
  #   index: "form:show",
  #   show: "form:show",
  #   update: "form:manage",
  #   delete: "form:delete",
  #   align_fields: "form:manage"
  # )

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Themes.Font
  alias WraftDoc.Themes.Fonts

  def swagger_definitions do
    %{
      FontCreateParams:
        swagger_schema do
          title("FontCreateParams")
          description("Parameters for creating a font")

          properties do
            name(:string, "Font name", required: true)
            files(Schema.array(:file), "List of font files", required: true)
          end

          example(%{
            name: "Roboto",
            files: [%Plug.Upload{path: "uploads/fonts/roboto.ttf", filename: "roboto.ttf"}]
          })
        end,
      FontUpdateParams:
        swagger_schema do
          title("FontUpdateParams")
          description("Parameters for updating a font")

          properties do
            name(:string, "Font name", required: false)
            files(Schema.array(:file), "List of font files", required: false)
          end

          example(%{
            name: "Roboto Updated",
            files: [%Plug.Upload{path: "uploads/fonts/roboto.ttf", filename: "roboto.ttf"}]
          })
        end,
      Font:
        swagger_schema do
          title("Font")
          description("A font resource")

          properties do
            id(:string, "Font ID")
            name(:string, "Font name")
            files(Schema.array(:file), "List of font files")
          end

          example(%{
            id: "1",
            name: "Roboto",
            files: [%Plug.Upload{path: "uploads/fonts/roboto.ttf", filename: "roboto.ttf"}]
          })
        end
    }
  end

  swagger_path :index do
    get("/fonts")
    summary("List all fonts")
    description("Retrieves a list of all fonts for the current user.")

    response(200, "OK", Schema.array(:Font))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns.current_user
    fonts = Fonts.list_fonts(current_user)
    render(conn, "index.json", fonts: fonts)
  end

  swagger_path :show do
    get("/fonts/{id}")
    summary("Get a font by ID")
    description("Retrieves a specific font by its ID.")
    produces("application/json")

    parameters do
      id(:path, :string, "Font ID", required: true)
    end

    response(200, "OK", Schema.ref(:Font))
    response(404, "Not Found")
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    font = Fonts.get_font(id)
    render(conn, "font.json", font: font)
  end

  swagger_path :create do
    post("/fonts")
    summary("Create a font")
    description("Creates a new font with a name and a list of files.")
    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Layout's name", required: true)

    parameter(:files, :formData, :file, "Font files (multiple allowed)",
      required: true,
      type: :file,
      collectionFormat: "multi"
    )

    response(201, "Font created", Schema.ref(:Font))
    response(400, "Bad request")
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, font} <- Fonts.create_font(current_user, params) do
      conn
      |> put_status(:created)
      |> render("font.json", font: font)
    end
  end

  swagger_path :update do
    put("/fonts/{id}")
    summary("Update a font")
    description("Updates an existing font's name and files list.")
    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Layout's name", required: true)

    parameter(:files, :formData, :file, "Font files (multiple allowed)",
      required: true,
      type: :file,
      collectionFormat: "multi"
    )

    response(200, "Font updated", Schema.ref(:Font))
    response(400, "Bad request")
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with {:ok, font} <- Fonts.update_font(current_user, id, params) do
      render(conn, "font.json", font: font)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/fonts/{id}")
    summary("Delete a font")
    description("Deletes a specific font by its ID.")

    parameters do
      id(:path, :string, "Font ID", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found")
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %Font{} = font <- Fonts.get_font(id),
         %Font{} <- Fonts.delete_font(font) do
      send_resp(conn, :no_content, "")
    end
  end
end
