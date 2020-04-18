defmodule WraftDocWeb.Api.V1.AssetController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Asset}

  def swagger_definitions do
    %{
      Asset:
        swagger_schema do
          title("Asset")
          description("An asset.")

          properties do
            id(:string, "The ID of the asset", required: true)
            name(:string, "Name of the asset")
            file(:string, "URL of the uploaded file")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Asset",
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

    response(200, "Ok", Schema.ref(:Asset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Asset{} = asset} <- Document.create_asset(current_user, params) do
      conn
      |> render(:asset, asset: asset)
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
    %{organisation_id: org_id} = conn.assigns[:current_user]

    with %{
           entries: assets,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.asset_index(org_id, params) do
      conn
      |> render("index.json",
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
  def show(conn, %{"id" => asset_uuid}) do
    with %Asset{} = asset <- Document.show_asset(asset_uuid) do
      conn
      |> render("show.json", asset: asset)
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
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Asset{} = asset <- Document.get_asset(uuid),
         {:ok, asset} <- Document.update_asset(asset, current_user, params) do
      conn
      |> render("asset.json", asset: asset)
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
  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %Asset{} = asset <- Document.get_asset(uuid),
         {:ok, %Asset{}} <- Document.delete_asset(asset, current_user) do
      conn
      |> render("asset.json", asset: asset)
    end
  end
end
