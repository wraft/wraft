defmodule WraftDocWeb.Api.V1.AssetController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset

  def swagger_definitions do
    %{
      Asset:
        swagger_schema do
          title("Asset")
          description("An asset.")

          properties do
            id(:string, "The ID of the asset", required: true)
            name(:string, "Name of the asset")
            type(:string, "Type of the asset - layout or theme")
            file(:string, "URL of the uploaded file")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Asset",
            type: "layout",
            file: "/signature.pdf",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ShowAsset:
        swagger_schema do
          title("Show asset")
          description("An asset and its details")

          properties do
            content(Schema.ref(:Asset))
            creator(Schema.ref(:User))
          end

          example(%{
            asset: %{
              id: "1232148nb3478",
              name: "Asset",
              type: "layout",
              file: "/signature.pdf",
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
      Assets:
        swagger_schema do
          title("All assets in an organisation")
          description("All assets that have been created under an organisation")
          type(:array)
          items(Schema.ref(:Asset))
        end,
      AssetsIndex:
        swagger_schema do
          properties do
            assets(Schema.ref(:Assets))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            assets: [
              %{
                id: "1232148nb3478",
                name: "Asset",
                type: "layout",
                file: "/signature.pdf",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end
    }
  end

  @doc """
  Create an asset.
  """
  swagger_path :create do
    post("/assets")
    summary("Create an asset")
    description("Create asset API")
    operation_id("create_asset")
    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Asset name", required: true)
    parameter(:file, :formData, :file, "Asset file to upload")
    parameter(:type, :formData, :string, "The type of asset - theme or layout or document")

    response(200, "Ok", Schema.ref(:Asset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Asset{} = asset} <- Assets.create_asset(current_user, params) do
      render(conn, :asset, asset: asset)
    end
  end

  @doc """
  Asset index.
  """
  swagger_path :index do
    get("/assets")
    summary("Asset index")
    description("API to get the list of all assets created so far under an organisation")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:AssetsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: assets,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Assets.asset_index(current_user, params) do
      render(conn, "index.json",
        assets: assets,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show asset.
  """
  swagger_path :show do
    get("/assets/{id}")
    summary("Show an asset")
    description("API to get all details of an asset")

    parameters do
      id(:path, :string, "ID of the asset", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowAsset))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => asset_id}) do
    current_user = conn.assigns.current_user

    with %Asset{} = asset <- Assets.show_asset(asset_id, current_user) do
      render(conn, "show.json", asset: asset)
    end
  end

  @doc """
  Get image
  """
  swagger_path :show_image do
    get("asset/image/{id}")
    summary("Get image")
    description("Api to get image")

    parameters do
      id(:path, :string, "Instance id", required: true)
      asset_id(:query, :string, "Image Asset ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Content))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show_image(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_image(conn, %{"id" => asset_id}) do
    with %Asset{} = asset <- Assets.get_asset(asset_id) do
      redirect(conn, external: Assets.get_image_url(asset))
    end
  end

  @doc """
  Update an asset.
  """
  swagger_path :update do
    put("/assets/{id}")
    summary("Update an asset")
    description("API to update an asset")

    consumes("multipart/form-data")

    parameter(:id, :path, :string, "asset id", required: true)
    parameter(:name, :formData, :string, "Asset name", required: true)
    parameter(:file, :formData, :file, "Asset file to upload")

    response(200, "Ok", Schema.ref(:Asset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Asset{} = asset <- Assets.get_asset(id, current_user),
         {:ok, asset} <- Assets.update_asset(asset, params) do
      render(conn, "asset.json", asset: asset)
    end
  end

  @doc """
  Delete an asset.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/assets/{id}")
    summary("Delete an asset")
    description("API to delete an asset")

    parameters do
      id(:path, :string, "asset id", required: true)
    end

    response(200, "Ok", Schema.ref(:Asset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Asset{} = asset <- Assets.get_asset(id, current_user),
         {:ok, %Asset{}} <- Assets.delete_asset(asset) do
      render(conn, "asset.json", asset: asset)
    end
  end
end
