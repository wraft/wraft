defmodule WraftDocWeb.Api.V1.FieldTypeController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.FieldType}

  def swagger_definitions do
    %{
      FieldTypeRequest:
        swagger_schema do
          title("Field type request")
          description("Field type request")

          properties do
            name(:string, "Name of the asset")
          end

          example(%{
            name: "Date"
          })
        end,
      FieldType:
        swagger_schema do
          title("Field type")
          description("A field type.")

          properties do
            id(:string, "The ID of the asset", required: true)
            name(:string, "Name of the asset")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Date",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      FieldTypes:
        swagger_schema do
          title("All field types")
          description("All filed types that have been created so far")
          type(:array)
          items(Schema.ref(:FieldType))
        end,
      FieldTypeIndex:
        swagger_schema do
          properties do
            assets(Schema.ref(:FieldTypes))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            field_types: [
              %{
                id: "1232148nb3478",
                name: "Date",
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
  Create a field type.
  """
  swagger_path :create do
    post("/field_types")
    summary("Create a field type")
    description("Create field type API")
    operation_id("create_field_type")

    parameters do
      field_type(:body, Schema.ref(:FieldTypeRequest), "Field Type to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:FieldType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %FieldType{} = field_type} <- Document.create_field_type(current_user, params) do
      conn
      |> render(:field_type, field_type: field_type)
    end
  end

  @doc """
  Field type index.
  """
  swagger_path :index do
    get("/field_types")
    summary("Field type index")
    description("API to get the list of all field typs created so far")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:FieldTypeIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    with %{
           entries: field_types,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.field_type_index(params) do
      conn
      |> render("index.json",
        field_types: field_types,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show fielf type.
  """
  swagger_path :show do
    get("/field_types/{id}")
    summary("Show a field type")
    description("API to show a field type")

    parameters do
      id(:path, :string, "ID of the field type", required: true)
    end

    response(200, "Ok", Schema.ref(:FieldType))
    response(404, "Not found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => field_type_uuid}) do
    with %FieldType{} = field_type <- Document.get_field_type(field_type_uuid) do
      conn
      |> render("field_type.json", field_type: field_type)
    end
  end

  @doc """
  Update a field type.
  """
  swagger_path :update do
    put("/field_types/{id}")
    summary("Update a field type")
    description("API to update a field type")

    parameters do
      id(:path, :string, "Field type id", required: true)
      field_type(:body, Schema.ref(:FieldTypeRequest), "Field Type to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Asset))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %FieldType{} = field_type <- Document.get_field_type(uuid),
         {:ok, field_type} <- Document.update_field_type(field_type, params) do
      conn
      |> render("field_type.json", field_type: field_type)
    end
  end

  # @doc """
  # Delete an asset.
  # """
  # swagger_path :delete do
  #   PhoenixSwagger.Path.delete("/assets/{id}")
  #   summary("Delete an asset")
  #   description("API to delete an asset")

  #   parameters do
  #     id(:path, :string, "asset id", required: true)
  #   end

  #   response(200, "Ok", Schema.ref(:Asset))
  #   response(422, "Unprocessable Entity", Schema.ref(:Error))
  #   response(401, "Unauthorized", Schema.ref(:Error))
  #   response(404, "Not found", Schema.ref(:Error))
  # end

  # @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def delete(conn, %{"id" => uuid}) do
  #   with %Asset{} = asset <- Document.get_asset(uuid),
  #        {:ok, %Asset{}} <- Document.delete_asset(asset) do
  #     conn
  #     |> render("asset.json", asset: asset)
  #   end
  # end
end
