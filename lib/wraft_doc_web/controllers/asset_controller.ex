defmodule WraftDocWeb.Api.V1.AssetController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

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
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Asset",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      AssetRequest:
        swagger_schema do
          title("Asset Request")
          description("Asset creation/updation request")

          properties do
            name(:string, "Asset name", required: true)
          end

          example(%{
            name: "Asset"
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

    parameters do
      asset(:body, Schema.ref(:AssetRequest), "Asset to be created", required: true)
    end

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

    response(200, "Ok", Schema.ref(:Assets))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    %{organisation_id: org_id} = conn.assigns[:current_user]
    assets = Document.asset_index(org_id)

    conn
    |> render("index.json", assets: assets)
  end

  @doc """
  Show instance.
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

    parameters do
      id(:path, :string, "asset id", required: true)

      asset(:body, Schema.ref(:AssetRequest), "Asset to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Asset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %Asset{} = asset <- Document.get_asset(uuid),
         {:ok, asset} <- Document.update_asset(asset, params) do
      conn
      |> render("asset.json", asset: asset)
    end
  end
end
