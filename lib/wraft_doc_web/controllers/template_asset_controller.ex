defmodule WraftDocWeb.Api.V1.TemplateAssetController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ContentTypes
  alias WraftDoc.DataTemplates
  alias WraftDoc.Layouts
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDoc.Themes
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.TemplateAsset, as: TemplateAssetSchema

  tags(["Template Assets"])

  operation(:create,
    summary: "Create a template asset",
    description: """
    Create a new template asset by either:
    - Uploading a ZIP file
    - Providing a URL to a ZIP file

    Only one of `asset_id` with type template_asset or `zip_url` should be provided.
    """,
    request_body:
      {"Asset id", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           file: %OpenApiSpex.Schema{type: :string, format: :binary, description: "Asset id"}
         }
       }},
    responses: [
      ok: {"OK", "application/json", TemplateAssetSchema.TemplateAsset},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"file" => file} = params) do
    current_user = conn.assigns.current_user

    with :ok <- TemplateAssets.validate_template_asset_file(file),
         {:ok, params, _} <-
           TemplateAssets.process_template_asset(params, :file, file),
         {:ok, %TemplateAsset{} = template_asset} <-
           TemplateAssets.create_template_asset(current_user, params) do
      render(conn, "template_asset.json", template_asset: template_asset)
    end
  end

  operation(:index,
    summary: "Template Asset index",
    description:
      "API to get the list of all template assets created so far under an organisation",
    parameters: [
      page: [in: :query, type: :integer, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.TemplateAssetsIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: template_assets,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- TemplateAssets.template_asset_index(current_user, params) do
      render(conn, "index.json",
        template_assets: template_assets,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a template asset",
    description: "API to get all details of a template asset",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the template asset", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.ShowTemplateAsset},
      not_found: {"Not found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => template_asset_id}) do
    current_user = conn.assigns.current_user

    with %TemplateAsset{} = template_asset <-
           TemplateAssets.show_template_asset(template_asset_id, current_user) do
      render(conn, "show.json", template_asset: template_asset)
    end
  end

  operation(:delete,
    summary: "Delete a template asset",
    description: "API to delete a template asset",
    parameters: [
      id: [in: :path, type: :string, description: "template asset id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.TemplateAsset},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %TemplateAsset{} = template_asset <- TemplateAssets.get_template_asset(id, current_user),
         {:ok, %TemplateAsset{}} <- TemplateAssets.delete_template_asset(template_asset) do
      render(conn, "template_asset.json", template_asset: template_asset)
    end
  end

  operation(:template_import,
    summary: "Build a template from an existing template asset",
    description:
      "Build a data template from a template asset to be used for document creation or further customization.",
    operation_id: "build_template",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the template asset to build",
        required: true
      ]
    ],
    request_body:
      {"Template import parameters", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           theme_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the theme to build the template from"
           },
           flow_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the flow to build the template from"
           },
           frame_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the frame to build the template from"
           },
           layout_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the layout to build the template from"
           },
           content_type_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the content type to build the template from"
           }
         }
       }},
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.TemplateImport},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec template_import(Plug.Conn.t(), map) :: Plug.Conn.t()
  def template_import(conn, %{"id" => template_asset_id} = params) do
    current_user = conn.assigns[:current_user]

    with %TemplateAsset{asset: asset} <-
           TemplateAssets.get_template_asset(template_asset_id, current_user),
         {:ok, downloaded_file_binary} <-
           TemplateAssets.download_zip_from_storage(asset),
         options <- TemplateAssets.format_opts(params),
         {:ok, result} <-
           TemplateAssets.import_template(current_user, downloaded_file_binary, options) do
      render(conn, "show_template.json", result: result)
    end
  end

  operation(:template_pre_import,
    summary: "Prepare template asset for import",
    description:
      "Check for missing items in template asset and identify what needs to be included",
    operation_id: "pre_import_template",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the template asset to pre-import",
        required: true
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.TemplatePreImport},
      not_found: {"Not found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec template_pre_import(Plug.Conn.t(), map) :: Plug.Conn.t()
  def template_pre_import(conn, %{"id" => template_asset_id}) do
    current_user = conn.assigns[:current_user]

    with %TemplateAsset{asset: asset} <-
           TemplateAssets.get_template_asset(template_asset_id, current_user),
         {:ok, downloaded_file_binary} <-
           TemplateAssets.download_zip_from_storage(asset),
         {:ok, result} <-
           TemplateAssets.pre_import_template(downloaded_file_binary) do
      render(conn, "template_pre_import.json", result: result)
    end
  end

  operation(:template_export,
    summary: "Export data template into a zip format",
    description: "This creates a zip file containing all assets of data template from its id",
    operation_id: "template_export",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the template asset to build",
        required: true
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.FileDownloadResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec template_export(Plug.Conn.t(), map) :: Plug.Conn.t()
  def template_export(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %WraftDoc.DataTemplates.DataTemplate{} = data_template <-
           DataTemplates.get_data_template(current_user, id),
         %WraftDoc.ContentTypes.ContentType{} = c_type <-
           ContentTypes.get_content_type(current_user, data_template.content_type_id),
         %WraftDoc.Layouts.Layout{} = layout <-
           Layouts.get_layout(c_type.layout_id, current_user),
         %WraftDoc.Themes.Theme{} = theme <-
           Themes.get_theme(c_type.theme_id, current_user),
         {:ok, zip_path} <-
           TemplateAssets.prepare_template_format(
             theme,
             layout,
             c_type,
             data_template,
             current_user
           ) do
      send_download(conn, {:file, zip_path}, filename: "#{data_template.title}.zip")
    end
  end

  operation(:list_public_templates,
    summary: "List Public Templates",
    description: "Fetches a list of all public templates available.",
    responses: [
      ok: {"Success", "application/json", TemplateAssetSchema.PublicTemplateList},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  def list_public_templates(conn, _params) do
    with {:ok, template_list} <- TemplateAssets.public_template_asset_index() do
      render(conn, "list_public_templates.json", %{templates: template_list})
    end
  end

  operation(:download_public_template,
    summary: "Get Download URL for Public Template",
    description: "Generates a pre-signed URL for downloading a specified public template file.",
    parameters: [
      file_name: [
        in: :path,
        type: :string,
        description: "Name of the template file to download",
        required: true
      ]
    ],
    responses: [
      ok:
        {"Pre-signed URL generated successfully", "application/json",
         TemplateAssetSchema.DownloadTemplateResponse},
      bad_request: {"Failed to generate pre-signed URL", "application/json", Error}
    ]
  )

  def download_public_template(conn, %{"file_name" => template_name}) do
    with {:ok, template_url} <- TemplateAssets.download_public_template(template_name) do
      render(conn, "download_public_template.json", %{template_url: template_url})
    end
  end

  operation(:import_public_template,
    summary: "Import template from public template asset",
    description:
      "Import a data template from a public template asset to be used for document creation or further customization.",
    # Changed from build_template to import_public_template to avoid conflict
    operation_id: "import_public_template",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the template asset to build",
        required: true
      ]
    ],
    request_body:
      {"Import public template parameters", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           theme_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the theme to build the template from"
           },
           flow_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the flow to build the template from"
           },
           frame_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the frame to build the template from"
           },
           layout_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the layout to build the template from"
           },
           content_type_id: %OpenApiSpex.Schema{
             type: :string,
             description: "ID of the content type to build the template from"
           }
         }
       }},
    responses: [
      ok: {"Ok", "application/json", TemplateAssetSchema.TemplateImport},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def import_public_template(conn, %{"id" => template_asset_id} = params) do
    current_user = conn.assigns[:current_user]

    with %TemplateAsset{} = template_asset <-
           TemplateAssets.get_template_asset(template_asset_id),
         {:ok, downloaded_file_binary} <-
           TemplateAssets.download_zip_from_storage(template_asset),
         options <- TemplateAssets.format_opts(params),
         {:ok, result} <-
           TemplateAssets.import_template(current_user, downloaded_file_binary, options) do
      render(conn, "show_template.json", result: result)
    end
  end
end
