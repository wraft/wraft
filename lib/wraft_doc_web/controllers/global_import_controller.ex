defmodule WraftDocWeb.Api.V1.GlobalImportController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    import_global_file: "global_import:manage",
    pre_import_global_file: "global_import:manage",
    validate_global_file: "global_import:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.GlobalFile
  alias WraftDoc.Utils.FileHelper
  alias WraftDoc.Utils.FileValidator
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.GlobalImport, as: GlobalImportSchema

  tags(["Global Import"])

  operation(:import_global_file,
    summary: "Import a global file",
    description: "Imports a global file using the provided asset ID and additional parameters.",
    request_body:
      {"Global file import data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Name of the global file"},
           description: %OpenApiSpex.Schema{
             type: :string,
             description: "Description of the global file"
           },
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "The ID of the asset to import"
           }
         }
       }},
    responses: [
      ok:
        {"File imported successfully", "application/json",
         GlobalImportSchema.GlobalImportResponse},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec import_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import_global_file(conn, %{"file" => %{path: file_path} = file} = params) do
    current_user = conn.assigns.current_user

    with :ok <- GlobalFile.validate_global_file(file),
         {:ok, _} <- FileValidator.validate_file(file_path),
         {:ok, metadata} <- FileHelper.get_file_metadata(file),
         metadata <-
           Map.merge(metadata, Map.take(params, ["name", "description"])),
         {:ok, %{view: view, template: template, assigns: assigns}} <-
           GlobalFile.import_global_asset(current_user, Map.merge(params, metadata)) do
      conn
      |> put_view(view)
      |> render(template, assigns)
    end
  end

  def import_global_file(_, _), do: {:error, "No file provided. Please upload a file."}

  operation(:pre_import_global_file,
    summary: "pre-import a global file",
    description:
      "Pre-imports and validates global file using the provided asset ID and additional parameters.",
    request_body:
      {"Global file pre-import data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Name of the global file"},
           description: %OpenApiSpex.Schema{
             type: :string,
             description: "Description of the global file"
           },
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "The ID of the asset to import"
           }
         },
         required: [:file]
       }},
    responses: [
      ok: {"ok", "application/json", GlobalImportSchema.GlobalPreImportResponse},
      bad_request: {"Bad request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec pre_import_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def pre_import_global_file(conn, %{"file" => file}) do
    current_user = conn.assigns.current_user

    with {:ok, response} <- GlobalFile.pre_import_global_file(current_user, file) do
      render(conn, "pre_import_global_file.json", %{
        response: response
      })
    end
  end

  def pre_import_global_file(_, _), do: {:error, "No file provided. Please upload a file."}

  operation(:re_validate_global_file,
    summary: "Validate a global file",
    description: "Validates a global file using the provided asset ID and additional parameters.",
    request_body:
      {"Global file validation data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Name of the global file"},
           description: %OpenApiSpex.Schema{
             type: :string,
             description: "Description of the global file"
           },
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "The ID of the asset to import"
           }
         },
         required: [:file]
       }},
    responses: [
      ok: {"ok", "application/json", GlobalImportSchema.GlobalFileValidationResponse},
      bad_request: {"Bad request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec re_validate_global_file(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def re_validate_global_file(conn, %{"file" => %{path: file_path} = file} = params) do
    current_user = conn.assigns.current_user

    with :ok <- GlobalFile.validate_global_file(file),
         {:ok, _} <- FileValidator.validate_file(file_path),
         {:ok, metadata} <- FileHelper.get_file_metadata(file),
         metadata <-
           Map.merge(metadata, Map.take(params, ["name", "description"])),
         :ok <-
           GlobalFile.re_validate_global_asset(current_user, Map.merge(params, metadata)) do
      render(conn, "global_file_validation.json", %{
        message: "Validation completed successfully"
      })
    end
  end

  def re_validate_global_file(_, _), do: {:error, "No file provided. Please upload a file."}
end
