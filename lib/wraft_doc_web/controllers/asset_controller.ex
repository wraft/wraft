defmodule WraftDocWeb.Api.V1.AssetController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset

  alias WraftDocWeb.Schemas.Asset, as: AssetSchema
  alias WraftDocWeb.Schemas.Content
  alias WraftDocWeb.Schemas.Error

  tags(["Assets"])

  operation(:create,
    summary: "Create an asset",
    description: "Create asset API",
    operation_id: "create_asset",
    request_body:
      {"Asset to create", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Asset name"},
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Asset file to upload"
           },
           type: %OpenApiSpex.Schema{
             type: :string,
             description: "The type of asset - theme or layout or document"
           }
         },
         required: [:name]
       }},
    responses: [
      ok: {"Ok", "application/json", AssetSchema.Asset},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Asset{} = asset} <- Assets.create_asset(current_user, params) do
      render(conn, :asset, asset: asset)
    end
  end

  operation(:index,
    summary: "Asset index",
    description: "API to get the list of all assets created so far under an organisation",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", AssetSchema.AssetsIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:show,
    summary: "Show an asset",
    description: "API to get all details of an asset",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the asset", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", AssetSchema.ShowAsset},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => asset_id}) do
    current_user = conn.assigns.current_user

    with %Asset{} = asset <- Assets.show_asset(asset_id, current_user) do
      render(conn, "show.json", asset: asset)
    end
  end

  operation(:show_image,
    summary: "Get image",
    description: "API to get image",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true],
      asset_id: [in: :query, type: :string, description: "Image Asset ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Content.Content},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show_image(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show_image(conn, %{"id" => asset_id}) do
    with %Asset{} = asset <- Assets.get_asset(asset_id) do
      redirect(conn, external: Assets.get_image_url(asset))
    end
  end

  operation(:update,
    summary: "Update an asset",
    description: "API to update an asset",
    parameters: [
      id: [in: :path, type: :string, description: "asset id", required: true]
    ],
    request_body:
      {"Asset updates", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Asset name"},
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Asset file to upload"
           }
         },
         required: [:name]
       }},
    responses: [
      ok: {"Ok", "application/json", AssetSchema.Asset},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Asset{} = asset <- Assets.get_asset(id, current_user),
         {:ok, asset} <- Assets.update_asset(asset, params) do
      render(conn, "asset.json", asset: asset)
    end
  end

  operation(:delete,
    summary: "Delete an asset",
    description: "API to delete an asset",
    parameters: [
      id: [in: :path, type: :string, description: "asset id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", AssetSchema.Asset},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Asset{} = asset <- Assets.get_asset(id, current_user),
         {:ok, %Asset{}} <- Assets.delete_asset(asset) do
      render(conn, "asset.json", asset: asset)
    end
  end
end
