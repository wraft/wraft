defmodule WraftDocWeb.Api.V1.FrameController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Frames
  alias WraftDoc.Frames.Frame
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Frame, as: FrameSchema

  tags(["Frames"])

  operation(:index,
    summary: "Frame index",
    description: "Frame index API",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Frame Name"],
      sort: [
        in: :query,
        type: :string,
        description: "Sort Keys => name, name_desc, inserted_at, inserted_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", FrameSchema.FrameIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: frames,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Frames.list_frames(current_user, params) do
      render(conn, "index.json",
        frames: frames,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:create,
    summary: "Create a new frame",
    description: "Create a new frame API",
    request_body:
      {"Frame file and thumbnail to upload", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           file: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Frame file to upload"
           },
           thumbnail: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Frame thumbnail to upload"
           }
         }
       }},
    responses: [
      ok: {"Created", "application/json", FrameSchema.Frame},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Frame{} = frame} <- Frames.create_frame(current_user, params) do
      render(conn, "create.json", frame: frame)
    end
  end

  operation(:show,
    summary: "Show a frame",
    description: "Show a frame API",
    parameters: [
      id: [in: :path, type: :string, description: "frame id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FrameSchema.ShowFrame},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Frame{} = frame <- Frames.get_frame(id, current_user) do
      render(conn, "show.json", frame: frame)
    end
  end

  operation(:delete,
    summary: "Delete a frame",
    description: "API to delete a frame",
    parameters: [
      id: [in: :path, type: :string, description: "frame id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FrameSchema.Frame},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %Frame{} = frame <- Frames.get_frame(uuid, current_user),
         {:ok, %Frame{}} <- Frames.delete_frame(frame) do
      render(conn, "create.json", frame: frame)
    end
  end
end
