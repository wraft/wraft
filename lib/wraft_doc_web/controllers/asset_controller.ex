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
end
