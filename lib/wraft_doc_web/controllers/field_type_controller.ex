defmodule WraftDocWeb.Api.V1.FieldTypeController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Fields
  alias WraftDoc.Fields.FieldType
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.FieldType, as: FieldTypeSchema

  tags(["Field Types"])

  operation(:create,
    summary: "Create a field type",
    description: "Create field type API",
    operation_id: "create_field_type",
    parameters: [],
    request_body:
      {"Field Type to be created", "application/json", FieldTypeSchema.FieldTypeRequest},
    responses: [
      ok: {"Ok", "application/json", FieldTypeSchema.FieldType},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %FieldType{} = field_type} <- Fields.create_field_type(current_user, params) do
      render(conn, :field_type, field_type: field_type)
    end
  end

  operation(:index,
    summary: "Field type index",
    description: "API to get the list of all field typs created so far",
    responses: [
      ok: {"Ok", "application/json", FieldTypeSchema.FieldTypeIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    with field_types <- Fields.field_type_index() do
      render(conn, "index.json", field_types: field_types)
    end
  end

  operation(:show,
    summary: "Show a field type",
    description: "API to show a field type",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the field type", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FieldTypeSchema.FieldType},
      not_found: {"Not found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => field_type_id}) do
    with %FieldType{} = field_type <- Fields.get_field_type(field_type_id) do
      render(conn, "field_type.json", field_type: field_type)
    end
  end

  operation(:update,
    summary: "Update a field type",
    description: "API to update a field type",
    parameters: [
      id: [in: :path, type: :string, description: "Field type id", required: true]
    ],
    request_body:
      {"Field Type to be updated", "application/json", FieldTypeSchema.FieldTypeRequest},
    responses: [
      ok: {"Ok", "application/json", FieldTypeSchema.FieldType},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with %FieldType{} = field_type <- Fields.get_field_type(id),
         {:ok, field_type} <- Fields.update_field_type(field_type, params) do
      render(conn, "field_type.json", field_type: field_type)
    end
  end

  operation(:delete,
    summary: "Delete a field type",
    description: "API to delete a field type",
    parameters: [
      id: [in: :path, type: :string, description: "field type id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FieldTypeSchema.FieldType},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %FieldType{} = field_type <- Fields.get_field_type(id),
         {:ok, %FieldType{}} <- Fields.delete_field_type(field_type) do
      render(conn, "field_type.json", field_type: field_type)
    end
  end
end
