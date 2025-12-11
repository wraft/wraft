defmodule WraftDocWeb.Api.V1.DocumentController do
  @moduledoc """
  Controller for document operations including DOCX import
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    import_docx: "template:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.DocConversion
  alias WraftDoc.Utils.MarkDownToProseMirror
  alias WraftDocWeb.Schemas

  tags(["Documents"])

  @doc """
  Import a DOCX file and convert it to ProseMirror JSON format
  """
  operation(:import_docx,
    summary: "Import DOCX file",
    description: "Import a DOCX file and convert it to ProseMirror JSON format for editing",
    request_body:
      {"DOCX file to import", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "DOCX file to upload"
           }
         },
         required: [:file]
       }},
    responses: [
      ok: {"Success", "application/json", Schemas.Document.ImportDocxResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

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
