defmodule WraftDocWeb.Api.V1.TemplateAssetController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "template_asset:manage",
    index: "template_asset:show",
    show: "template_asset:show",
    update: "template_asset:manage",
    delete: "template_asset:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document.DataTemplate
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset

  @doc """
  Creates a new template asset.
  """
  def swagger_definitions do
    %{
      TemplateAsset:
        swagger_schema do
          title("Template Asset")
          description("A Template asset bundle.")

          properties do
            id(:string, "The ID of the template asset", required: true, format: "uuid")
            name(:string, "Name of the template asset")
            file(:string, "URL of the uploaded file")
            inserted_at(:string, "When the template asset was inserted", format: "ISO-8601")
            updated_at(:string, "When the template asset was last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Template Asset",
            file: "/contract.zip",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ShowTemplateAsset:
        swagger_schema do
          title("Show template asset")
          description("A template asset and its details")

          properties do
            # Ensuring consistency with key naming
            template_asset(Schema.ref(:TemplateAsset))
            creator(Schema.ref(:User))
          end

          example(%{
            template_asset: %{
              id: "1232148nb3478",
              name: "Template Asset",
              file: "/contract.zip",
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
      TemplateAssets:
        swagger_schema do
          title("All template assets in an organisation")
          description("All template assets that have been created under an organisation")
          type(:array)
          items(Schema.ref(:TemplateAsset))
        end,
      TemplateAssetsIndex:
        swagger_schema do
          properties do
            template_assets(Schema.ref(:TemplateAssets))
            page_number(:integer, "Page number", minimum: 0)
            total_pages(:integer, "Total number of pages", minimum: 0)
            total_entries(:integer, "Total number of contents", minimum: 0)
          end

          example(%{
            template_assets: [
              %{
                id: "1232148nb3478",
                name: "Template Asset",
                file: "/contract.zip",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end,
      ShowDataTemplate:
        swagger_schema do
          title("Data template and all its details")
          description("API to show a data template and all its details")

          properties do
            data_template(Schema.ref(:LayoutAndEngine))
            creator(Schema.ref(:User))
            content_type(Schema.ref(:ContentTypeWithoutFields))
          end

          example(%{
            data_template: %{
              id: "1232148nb3478",
              title: "Main Template",
              title_template: "Letter for [user]",
              data: "Hi [user]",
              serialized: %{title: "Offer letter of [client]", data: "Hi [user]"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end
    }
  end

  @doc """
  Create a template asset.
  """
  swagger_path :create do
    post("/template_assets")
    summary("Create a template asset")
    description("Create a new template asset and process the uploaded ZIP file")
    operation_id("create_asset")
    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Template Asset name", required: true)
    parameter(:zip_file, :formData, :file, "Template Asset zip file to upload", required: true)

    response(200, "OK", Schema.ref(:TemplateAsset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(500, "Internal Server Error", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %TemplateAsset{} = template_asset} <-
           TemplateAssets.create_template_asset(current_user, params),
         {:ok, downloaded_zip_binary} <-
           TemplateAssets.download_zip_from_minio(current_user, template_asset.id),
         {:ok, template_map} <- TemplateAssets.get_wraft_json_map(downloaded_zip_binary),
         updated_params <- Map.merge(params, %{"wraft_json" => template_map}),
         {:ok, %TemplateAsset{} = updated_template_asset} <-
           TemplateAssets.update_template_asset_json(template_asset, updated_params),
         file_entries <-
           TemplateAssets.template_asset_file_list(downloaded_zip_binary) do
      render(conn, "template_asset.json",
        template_asset: updated_template_asset,
        file_entries: file_entries
      )
    end
  end

  @doc """
  Template Asset index.
  """
  swagger_path :index do
    get("/template_assets")
    summary("Template Asset index")
    description("API to get the list of all template assets created so far under an organisation")

    parameter(:page, :query, :integer, "Page number")

    response(200, "Ok", Schema.ref(:TemplateAssetsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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

  @doc """
  Show template asset.
  """
  swagger_path :show do
    get("/template_assets/{id}")
    summary("Show a template asset")
    description("API to get all details of a template asset")

    parameters do
      id(:path, :string, "ID of the template asset", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowTemplateAsset))
    response(404, "Not found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => template_asset_id}) do
    current_user = conn.assigns.current_user

    with %TemplateAsset{} = template_asset <-
           TemplateAssets.show_template_asset(template_asset_id, current_user) do
      render(conn, "show.json", template_asset: template_asset)
    end
  end

  @doc """
  Update a template asset.
  """
  swagger_path :update do
    put("/template_assets/{id}")
    summary("Update a template asset")
    description("API to update a template asset")

    consumes("multipart/form-data")

    parameter(:id, :path, :string, "template asset id", required: true)
    parameter(:name, :formData, :string, "Template Asset name", required: true)
    parameter(:zip_file, :formData, :file, "Template Asset file to upload", required: false)

    response(200, "Ok", Schema.ref(:TemplateAsset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %TemplateAsset{} = template_asset <- TemplateAssets.get_template_asset(id, current_user),
         {:ok, template_asset} <- TemplateAssets.update_template_asset(template_asset, params) do
      render(conn, "template_asset.json", template_asset: template_asset)
    end
  end

  @doc """
  Delete a template asset.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/template_assets/{id}")
    summary("Delete a template asset")
    description("API to delete a template asset")

    parameters do
      id(:path, :string, "template asset id", required: true)
    end

    response(200, "Ok", Schema.ref(:TemplateAsset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %TemplateAsset{} = template_asset <- TemplateAssets.get_template_asset(id, current_user),
         {:ok, %TemplateAsset{}} <- TemplateAssets.delete_template_asset(template_asset) do
      render(conn, "template_asset.json", template_asset: template_asset)
    end
  end

  @doc """
  Builds a template from an existing template asset.
  """
  swagger_path :template_import do
    get("/template_assets/{id}/import")
    summary("Build a template from an existing template asset")

    description(
      "Build a data template from a template asset to be used for document creation or further customization."
    )

    operation_id("build_template")
    consumes("application/json")

    parameters do
      id(:path, :string, "ID of the template asset to build", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowDataTemplate))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec template_import(Plug.Conn.t(), map) :: Plug.Conn.t()
  def template_import(conn, %{"id" => template_asset_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, downloaded_zip_binary} <-
           TemplateAssets.download_zip_from_minio(current_user, template_asset_id),
         %DataTemplate{} = data_template <-
           TemplateAssets.import_template(current_user, downloaded_zip_binary) do
      render(conn, "show_template.json", %{template: data_template})
    end
  end
end
