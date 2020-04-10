defmodule WraftDocWeb.Api.V1.BlockController do
  use WraftDocWeb, :controller

  use PhoenixSwagger
  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{Document, Document.Block}

  def swagger_defnitions do
    %{
      BlockRequest:
        swagger_schema do
          title("Block Request")
          description("A block to Be created to add to instances")

          properties do
            name(:string, "Block name", required: true)
            btype(:string, "Block type", required: true)
            dataset(:map, "Dataset for creating charts", required: true)
            api_route(:string, "Api route to generate chart")
            endpoint(:string, "name of the endpoint going to choose")
          end

          example(%{
            name: "Farming",
            btype: "pie",
            api_route: "http://localhost:8080/chart",
            endpoint: "blocks_api",
            dataset: %{
              data: [
                %{
                  value: 10,
                  label: "Adakka"
                },
                %{
                  value: 20,
                  label: "Tenga"
                },
                %{
                  value: 5,
                  label: "Vanila"
                },
                %{
                  value: 60,
                  label: "Pazham"
                },
                %{
                  value: 80,
                  label: "Kurumulak"
                },
                %{
                  value: 70,
                  label: "Urulakiyang"
                },
                %{
                  value: 90,
                  label: "Gothamb"
                }
              ],
              width: 512,
              height: 512,
              backgroundColor: "transparent",
              format: "svg",
              type: "pie"
            }
          })
        end,
      Block:
        swagger_schema do
          title("Block")
          description("A Block")

          properties do
            name(:string, "Block name", required: true)
            btype(:string, "Block type", required: true)
            dataset(:map, "Dataset for creating charts", required: true)
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
            api_route(:string, "Api route to generate chart")
            endpoint(:string, "name of the endpoint going to choose")
          end

          example(%{
            name: "Farming",
            btype: "pie",
            api_route: "http://localhost:8080/chart",
            endpoint: "blocks_api",
            file_url:
              "/home/sadique/Documents/org.functionary/go/src/blocks_api/002dc916-4444-4072-a8aa-85a32c5a65ea.svg",
            dataset: %{
              data: [
                %{
                  value: 10,
                  label: "Adakka"
                },
                %{
                  value: 20,
                  label: "Tenga"
                },
                %{
                  value: 5,
                  label: "Vanila"
                },
                %{
                  value: 60,
                  label: "Pazham"
                },
                %{
                  value: 80,
                  label: "Kurumulak"
                },
                %{
                  value: 70,
                  label: "Urulakiyang"
                },
                %{
                  value: 90,
                  label: "Gothamb"
                }
              ],
              width: 512,
              height: 512,
              backgroundColor: "transparent",
              format: "svg",
              type: "pie"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end
    }
  end

  @doc """
  Create New one
  """
  swagger_path :create do
    post("/blocks")
    summary("Generate blocks")
    description("Create a block")
    operation_id("create_block")

    parameters do
      block(:body, Schema.ref(:BlockRequest), "Block to Create", required: true)
    end

    response(200, "Created", Schema.ref(:Block))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %{"url" => file_url} <- Document.generate_chart(params) do
      params = Map.put(params, "file_url", file_url)

      with %Block{} = block <- Document.create_block(current_user, params) do
        conn
        |> put_status(:created)
        |> render("create.json", block: block)
      end
    end
  end

  swagger_path :update do
    put("/blocks")
    summary("Update blocks")
    description("Update a block")
    operation_id("update_block")

    parameters do
      id(:path, :string, "block id", required: true)
      block(:body, Schema.ref(:BlockRequest), "Block to update", required: true)
    end

    response(201, "Accepted", Schema.ref(:Block))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %Block{} = block <- Document.get_block(uuid),
         %Block{} = block <- Document.update_block(block, params) do
      conn
      |> put_status(:created)
      |> render("update.json", block: block)
    end
  end

  swagger_path :show do
    get("/blocks/:id")
    summary("Show a block")
    description("Show a block details")
    operation_id("show_block")

    parameters do
      id(:path, :string, "Block id", required: true)
    end

    response(200, "Ok", Schema.ref(:Block))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => uuid}) do
    with %Block{} = block <- Document.get_block(uuid) do
      conn
      |> render("show.json", block: block)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/block")
    summary("Delete a block")
    description("Delete a block from database")
    operation_id("delete_block")

    parameters do
      id(:path, "Block id", required: true)
    end

    response(200, "Ok", Schema.ref(:Block))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => uuid}) do
    with %Block{} = block <- Document.get_block(uuid),
         {:ok, %Block{}} <- Document.delete_block(block) do
      conn |> render("block.json", block: block)
    end
  end
end
