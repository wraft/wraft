defmodule WraftDocWeb.Api.V1.GlobalImportController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    import_global_file: "global_import:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.GlobalFile
  alias WraftDoc.Utils.FileHelper
  alias WraftDoc.Utils.FileValidator

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
      file(:formData, :file, "The ID of the asset to import", required: true)
    end

    response(200, "File imported successfully", Schema.ref(:GlobalImportResponse))

    response(400, "Bad Request")
    response(404, "Asset not found")
  end

  @spec import_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import_global_file(conn, %{"file" => %{path: file_path} = file} = params) do
    current_user = conn.assigns.current_user

    with {:ok, _} <- FileValidator.validate_file(file_path),
         {:ok, metadata} <- FileHelper.get_file_metadata(file),
         {:ok, %{view: view, template: template, assigns: assigns}} <-
           GlobalFile.import_global_asset(current_user, Map.merge(params, metadata)) do
      conn
      |> put_view(view)
      |> render(template, assigns)
    end
  end
end
