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

  def swagger_definitions do
    %{
      GlobalImportResponse:
        swagger_schema do
          title("Global Import Response")
          description("Response schema for a successful global file import")

          properties do
            frame(Schema.ref(:Frame), "Frame response")
            template_asset(Schema.ref(:TemplateAsset), "Template Asset response")
          end
        end
    }
  end

  @doc """
  Imports a global file.
  """
  swagger_path :import_global_file do
    post("/global_asset/import")
    summary("Import a global file")
    description("Imports a global file using the provided asset ID and additional parameters.")

    parameters do
      asset_id(:path, :string, "The ID of the asset to import", required: true)
    end

    response(200, "File imported successfully", Schema.ref(:GlobalImportResponse))

    response(400, "Bad Request")
    response(404, "Asset not found")
  end

  @spec import_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import_global_file(conn, %{"asset_id" => asset_id} = params) do
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
