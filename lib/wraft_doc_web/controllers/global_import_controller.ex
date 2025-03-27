defmodule WraftDocWeb.Api.V1.GlobalImportController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    import_global_file: "file:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.GlobalFile

  @doc """
  Imports a global file.
  """
  @spec import_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import_global_file(conn, %{"asset" => asset_id} = params) do
    current_user = conn.assigns.current_user

    with %Asset{} = asset <- Assets.get_asset(asset_id, current_user),
         {:ok, %{view: view, template: template, assigns: assigns}} <-
           GlobalFile.import_global_asset(current_user, asset, params) do
      conn
      |> put_view(view)
      |> render(template, assigns)
    end
  end
end
