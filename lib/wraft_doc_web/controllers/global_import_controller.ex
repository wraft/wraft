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
        end,
      GlobalPreImportResponse:
        swagger_schema do
          title("Global Pre Import Response")
          description("Response schema for a successful global file pre-import")

          properties do
            meta(:string, "Wraft JSON")
            file_details(:string, "File details")
            errors(:array, "Errors", items: :string)
          end

          example(%{
            file_details: %{
              file_name: "example.zip",
              file_size: 123_456,
              file_type: "application/zip",
              files: ["assets/logo.svg", "template.typst", "default.typst"]
            },
            meta: %{},
            errors: [
              %{
                type: "File_validation",
                error: "Invalid file"
              }
            ]
          })
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

  def import_global_file(_, _), do: {:error, "File not found"}

  @doc """
  Pre-imports global file.
  """
  swagger_path :pre_import_global_file do
    post("/global_asset/pre_import")
    summary("pre-import a global file")

    description(
      "Pre-imports and validates global file using the provided asset ID and additional parameters."
    )

    parameters do
      file(:formData, :file, "The ID of the asset to import", required: true)
    end

    response(200, "ok", Schema.ref(:GlobalPreImportResponse))
    response(400, "Bad request", Schema.ref(:Error))
  end

  @spec pre_import_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pre_import_global_file(conn, %{"file" => file}) do
    with {:ok, response} <- GlobalFile.pre_import_global_file(file) do
      render(conn, "pre_import_global_file.json", %{
        response: response
      })
    end
  end

  def pre_import_global_file(_, _), do: {:error, "File not found"}

  # @doc """
  # Validates a global file.
  # """
  # # TODO update swagger
  # swagger_path :validate_global_file do
  #   post("/global_asset/validate")
  #   summary("Validate a global file")

  #   description("Validates a global file using the provided asset ID and additional parameters.")

  #   parameters do
  #     file(:formData, :file, "The ID of the asset to import", required: true)
  #   end

  #   response(200, "ok", Schema.ref(:GlobalPreImportResponse))
  #   response(400, "Bad request", Schema.ref(:Error))
  # end
  # @spec validate_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # def validate_global_file(conn, %{"file" => %{path: file_path} = file} = params) do
  #   with {:ok, _} <- FileValidator.validate_file(file_path),
  #        {:ok, metadata} <- FileHelper.get_file_metadata(file),
  #        :ok <-
  #          GlobalFile.validate_global_asset(Map.merge(params, metadata)) do
  #     render(conn, "global_file_validation.json", %{
  #       message: "Validation completed successfully"
  #     })
  #   else
  #     {:ok, result} ->
  #       render(conn, "global_file_validation.json", %{
  #         message: "Validation completed successfully",
  #         result: result
  #       })

  #     {:error, reason} ->
  #       {:error, reason}
  #   end
  # end
end
