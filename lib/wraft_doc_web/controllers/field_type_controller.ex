defmodule WraftDocWeb.Api.V1.FieldTypeController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "field_type:manage",
    index: "field_type:show",
    show: "field_type:show",
    update: "field_type:manage",
    delete: "field_type:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document
  alias WraftDoc.Document.FieldType

  def swagger_definitions do
    %{
      FieldTypeRequest:
        swagger_schema do
          title("Field type request")
          description("Field type request")

          properties do
            name(:string, "Name of the field type")
            description(:string, "Description of the field type")
            meta(:map, "Meta data of the field type")
            validations(Schema.ref(:Validations))
          end

          example(%{
            name: "Date",
            description: "A date field",
            meta: %{},
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ]
          })
        end,
      FieldType:
        swagger_schema do
          title("Field type")
          description("A field type.")

          properties do
            id(:string, "The ID of the field type", required: true)
            name(:string, "Name of the field type")
            meta(:map, "Meta data of the field type")
            description(:string, "Description of the field type")
            validations(Schema.ref(:Validations))
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "bdf2a17d-c40a-4cd9-affc-d649709a0ed3",
            name: "Date",
            description: "A date field",
            meta: %{},
            validations: [
              %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
            ],
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
            field_types(Schema.ref(:FieldTypes))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            field_types: [
              %{
                id: "1232148nb3478",
                name: "Date",
                description: "A date field",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end,
      Validations:
        swagger_schema do
          title("Validation array")
          description("List of validations")
          type(:array)
          items(Schema.ref(:Validation))
        end,
      Validation:
        swagger_schema do
          title("Validation")
          description("A validation object")

          properties do
            validation(Schema.ref(:ValidationRule))
            error_message(:string, "Error message when validation fails")
          end

          example(%{
            validation: %{rule: "required", value: true},
            error_message: "can't be blank"
          })
        end,
      ValidationRule:
        swagger_schema do
          title("Validation rule")
          description("A validation rule")
          type(:object)

          properties do
            rule(:string, "Validation rule")
            value([:string, :number, :boolean, :array], "Validation value")
          end
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
      render(conn, :field_type, field_type: field_type)
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
      render(conn, "index.json",
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
  def show(conn, %{"id" => field_type_id}) do
    with %FieldType{} = field_type <- Document.get_field_type(field_type_id) do
      render(conn, "field_type.json", field_type: field_type)
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

    response(200, "Ok", Schema.ref(:FieldType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with %FieldType{} = field_type <- Document.get_field_type(id),
         {:ok, field_type} <- Document.update_field_type(field_type, params) do
      render(conn, "field_type.json", field_type: field_type)
    end
  end

  @doc """
  Delete a field type.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/field_types/{id}")
    summary("Delete a field type")
    description("API to delete a field type")

    parameters do
      id(:path, :string, "field type id", required: true)
    end

    response(200, "Ok", Schema.ref(:FieldType))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %FieldType{} = field_type <- Document.get_field_type(id),
         {:ok, %FieldType{}} <- Document.delete_field_type(field_type) do
      render(conn, "field_type.json", field_type: field_type)
    end
  end
end
