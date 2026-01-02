defmodule WraftDocWeb.Api.V1.CommentController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Comments
  alias WraftDoc.Comments.Comment
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDocWeb.Schemas.Comment, as: CommentSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Comments"])

  operation(:create,
    summary: "Create comment",
    description: "Create comment API",
    request_body: {"Comment to be created", "application/json", CommentSchema.CommentRequest},
    responses: [
      ok: {"Ok", "application/json", CommentSchema.Comment},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"master_id" => document_id, "type" => "guest"} = params) do
    current_user = conn.assigns.current_user

    with true <- Documents.has_access?(current_user, document_id),
         %Comment{} = comment <- Comments.create_comment(current_user, params) do
      render(conn, "comment.json", comment: comment)
    end
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Comment{id: comment_id, master_id: master_id} =
           comment <-
           Comments.create_comment(current_user, params) do
      Task.start(fn ->
        Comments.comment_notification(
          current_user,
          comment_id,
          master_id
        )
      end)

      # Trigger webhook for comment added (only if it's a document comment)
      if comment.master do
        Task.start(fn -> trigger_comment_webhook(comment, current_user) end)
      end

      render(conn, "comment.json", comment: comment)
    end
  end

  operation(:index,
    summary: "Comment index",
    description: "API to get the list of all comments created under a master",
    parameters: [
      master_id: [in: :query, type: :string, description: "Document id"],
      page: [in: :query, type: :string, description: "Page number"],
      page_size: [in: :query, type: :string, description: "Page size"]
    ],
    responses: [
      ok: {"Ok", "application/json", CommentSchema.CommentIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: comments,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Comments.comment_index(current_user, params) do
      render(conn, "index.json",
        comments: comments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:reply,
    summary: "Comment replies",
    description: "API to get the list of replies under a comment",
    parameters: [
      id: [in: :path, type: :string, description: "comment_id"],
      master_id: [in: :query, type: :string, description: "Document id"],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", CommentSchema.CommentIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec reply(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reply(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: comments,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Comments.comment_replies(current_user, params) do
      render(conn, "index.json",
        comments: comments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a comment",
    description: "API to show details of a comment",
    parameters: [
      id: [in: :path, type: :string, description: "comment id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", CommentSchema.Comment},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.show_comment(id, current_user) do
      render(conn, "comment.json", comment: comment)
    end
  end

  operation(:update,
    summary: "Update a comment",
    description: "API to update a comment",
    parameters: [
      id: [in: :path, type: :string, description: "comment id", required: true]
    ],
    request_body: {"Comment to be updated", "application/json", CommentSchema.CommentRequest},
    responses: [
      ok: {"Ok", "application/json", CommentSchema.Comment},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.get_comment(id, current_user),
         %Comment{} = comment <- Comments.update_comment(comment, params) do
      render(conn, "comment.json", comment: comment)
    end
  end

  operation(:resolve,
    summary: "Resolve a comment",
    description: "API to resolve a comment",
    parameters: [
      id: [in: :path, type: :string, description: "comment id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", CommentSchema.Comment},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec resolve(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def resolve(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.get_comment(id, current_user),
         %Comment{} = comment <- Comments.resolve_comment(comment, current_user) do
      render(conn, "comment.json", comment: comment)
    end
  end

  operation(:delete,
    summary: "Delete a comment",
    description: "API to delete a comment",
    parameters: [
      id: [in: :path, type: :string, description: "comment id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", CommentSchema.DeleteCommentResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.get_comment(id, current_user),
         {:ok, %Comment{}} <- Comments.delete_comment(comment) do
      render(conn, "delete.json", comment: comment)
    end
  end

  # Private function to handle webhook trigger for document comments
  defp trigger_comment_webhook(comment, current_user) do
    case Documents.get_instance(comment.master_id, %{
           current_org_id: comment.organisation_id
         }) do
      %Instance{} = instance ->
        comment_data = %{
          id: comment.id,
          comment: comment.comment,
          user_id: current_user.id,
          user_name: current_user.name,
          user_email: current_user.email,
          inserted_at: comment.inserted_at
        }

        WraftDoc.Webhooks.EventTrigger.trigger_document_comment_added(
          instance,
          comment_data
        )

      _ ->
        :ok
    end
  end
end
