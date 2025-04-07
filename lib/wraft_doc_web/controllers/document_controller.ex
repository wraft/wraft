defmodule WraftDocWeb.Api.V1.DocumentController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    import_docx: "template:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.DocConversion
  alias WraftDoc.Utils.MarkDownToProseMirror

  def swagger_definitions do
    %{
      ImportDocxResponse:
        swagger_schema do
          title("Import Docx Response")
          description("Response for importing docx file")

          properties do
            prosemirror(:map, "ProseMirror JSON")
          end

          example(%{
            prosemirror: %{
              "type" => "doc",
              "content" => [
                %{
                  "type" => "heading",
                  "attrs" => %{"level" => 1},
                  "content" => [%{"type" => "text", "text" => "Hello"}]
                },
                %{
                  "type" => "paragraph",
                  "content" => [%{"type" => "text", "text" => "World"}]
                }
              ]
            }
          })
        end
    }
  end

  swagger_path :import_docx do
    post("/import_docx")
    summary("Import docx file")
    description("Import docx file")
    produces("application/json")
    consumes("multipart/form-data")
    parameter(:file, :formData, :file, "DOCX file to upload", required: true)

    response(200, "Success", Schema.ref(:ImportDocxResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec import_docx(Plug.Conn.t(), map) :: Plug.Conn.t()
  def import_docx(conn, %{"file" => %Plug.Upload{path: docx_file_path, filename: filename}}) do
    with ".docx" <- Path.extname(filename),
         {:ok, markdown} <- DocConversion.convert(docx_file_path) do
      render(conn, "import_docx.json",
        prosemirror_data: MarkDownToProseMirror.to_prosemirror(markdown)
      )
    else
      _ ->
        body = Jason.encode!(%{errors: "Invalid file format"})
        conn |> put_resp_content_type("application/json") |> send_resp(422, body)
    end
  end
end
