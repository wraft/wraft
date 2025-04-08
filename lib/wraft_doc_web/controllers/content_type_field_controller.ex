defmodule WraftDocWeb.Api.V1.ContentTypeFieldController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.Authorized, delete: "variant:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField

  @doc """
  Delete a Content Type Field.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/content_type/{content_type_id}/field/{field_id}")
    summary("Delete a Content Type Field")
    description("API to delete a content type field")

    parameters do
      id(:path, :string, "content type id", required: true)
      field_id(:path, :string, "content type field id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContentType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
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
