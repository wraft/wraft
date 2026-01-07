defmodule WraftDocWeb.Api.V1.ContentTypeFieldController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.Authorized, delete: "variant:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDocWeb.Schemas.Error

  tags(["Content Type Fields"])

  operation(:delete,
    summary: "Delete a Content Type Field",
    description: "API to delete a content type field",
    parameters: [
      content_type_id: [in: :path, type: :string, description: "content type id", required: true],
      field_id: [in: :path, type: :string, description: "content type field id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", WraftDocWeb.Schemas.ContentType.ShowContentType},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"content_type_id" => content_type_id, "field_id" => _field_id} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentTypeField{} = content_type_field <- ContentTypes.get_content_type_field(params),
         :ok <- ContentTypes.delete_content_type_field(content_type_field),
         %ContentType{} = content_type <-
           ContentTypes.get_content_type(current_user, content_type_id) do
      conn
      |> put_view(WraftDocWeb.Api.V1.ContentTypeView)
      |> render("show.json", content_type: content_type)
    end
  end
end
