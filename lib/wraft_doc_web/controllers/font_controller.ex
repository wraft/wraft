defmodule WraftDocWeb.Api.V1.FontController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug(WraftDocWeb.Plug.AddActionLog)

  # plug(WraftDocWeb.Plug.Authorized,
  #   create: "form:manage",
  #   index: "form:show",
  #   show: "form:show",
  #   update: "form:manage",
  #   delete: "form:delete",
  #   align_fields: "form:manage"
  # )

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Themes.Fonts
  # alias WraftDoc.Themes.Fonts.Font

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    fonts = Fonts.list_fonts(current_user)
    render(conn, "index.json", fonts: fonts)
  end

  def show(conn, %{"id" => id}) do
    font = Fonts.get_font(id)
    render(conn, "font.json", font: font)
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, font} <- Fonts.create_font(current_user, params) do
      conn
      |> put_status(:created)
      |> render("font.json", font: font)
    end
  end
end
