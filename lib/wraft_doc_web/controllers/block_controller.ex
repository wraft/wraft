defmodule WraftDocWeb.Api.V1.BlockController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDocWeb.Schemas

  plug(WraftDocWeb.Plug.AddActionLog)

  plug WraftDocWeb.Plug.Authorized,
    create: "block:manage",
    update: "block:manage",
    show: "block:show",
    delete: "block:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Blocks
  alias WraftDoc.Blocks.Block
  alias WraftDoc.Documents
  alias WraftDoc.Search.TypesenseServer, as: Typesense

  # tags(["Blocks"])

  @doc """
  Create New one
  """
  operation(:create,
    summary: "Generate blocks",
    description: "Create a block",
    request_body:
      {"Block data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string},
           btype: %OpenApiSpex.Schema{type: :string},
           description: %OpenApiSpex.Schema{type: :string},
           dataset: %OpenApiSpex.Schema{type: :object},
           api_route: %OpenApiSpex.Schema{type: :string},
           endpoint: %OpenApiSpex.Schema{type: :string},
           input: %OpenApiSpex.Schema{type: :string, format: :binary}
         }
       }},
    responses: [
      created: {"Created", "application/json", Schemas.Block.Block},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()

  def create(conn, params) do
    current_user = conn.assigns.current_user

    case Documents.generate_chart(params) do
      %{"url" => file_url} ->
        params =
          Map.merge(params, %{
            "file_url" => file_url,
            "tex_chart" => Documents.generate_tex_chart(params)
          })

        with %Block{} = block <- Blocks.create_block(current_user, params) do
          Typesense.create_document(block)

          conn
          |> put_status(:created)
          |> render("create.json", block: block)
        end

      %{"error" => message} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", message: message)
    end
  end

  operation(:update,
    summary: "Update blocks",
    description: "Update a block",
    parameters: [
      id: [in: :path, type: :string, description: "block id", required: true]
    ],
    request_body: {"Block to update", "application/json", Schemas.Block.BlockRequest},
    responses: [
      created: {"Accepted", "application/json", Schemas.Block.Block},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    case Documents.generate_chart(params) do
      %{"url" => file_url} ->
        Map.merge(params, %{
          "file_url" => file_url,
          "tex_chart" => Documents.generate_tex_chart(params)
        })

        with %Block{} = block <- Blocks.get_block(id, current_user),
             %Block{} = block <- Blocks.update_block(block, params) do
          Typesense.update_document(block)
          render(conn, "update.json", block: block)
        end

      %{"error" => message} ->
        conn
        |> put_status(:bad_request)
        |> render("error.json", message: message)
    end
  end

  operation(:show,
    summary: "Show a block",
    description: "Show a block details",
    parameters: [
      id: [in: :path, type: :string, description: "Block id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Block.Block},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Block{} = block <- Blocks.get_block(id, current_user) do
      render(conn, "show.json", block: block)
    end
  end

  operation(:delete,
    summary: "Delete a block",
    description: "Delete a block from database",
    parameters: [
      id: [in: :path, type: :string, description: "Block id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Block.Block},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Block{} = block <- Blocks.get_block(id, current_user),
         {:ok, %Block{}} <- Blocks.delete_block(block) do
      Typesense.delete_document(block.id, "block")
      render(conn, "block.json", block: block)
    end
  end
end
