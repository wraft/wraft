defmodule WraftDocWeb.Api.V1.CommentController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "comment:manage",
    index: "comment:show",
    reply: "comment:manage",
    show: "comment:show",
    update: "comment:manage",
    delete: "comment:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Comment
  alias WraftDoc.Comments
  alias WraftDoc.Document
  alias WraftDoc.Notifications

  def swagger_definitions do
    %{
      CommentRequest:
        swagger_schema do
          title("Comment Request")
          description("Create comment request.")

          properties do
            comment(:string, "The Comment to post", required: true)
            meta(:map, "Meta data of inline comments")
            is_parent(:boolean, "Declare the comment is parent or child", required: true)
            parent_id(:string, "Parent id of a child comment", required: true)
            master(:string, "Comments master", required: true)
            master_id(:string, "master id of the comment", required: true)
          end

          example(%{
            comment: "a sample comment",
            is_parent: true,
            parent_id: nil,
            master: "instance",
            meta: %{block: "introduction", line: 12},
            master_id: "32232sdffasdfsfdfasdfsdfs"
          })
        end,
      Comment:
        swagger_schema do
          title("Comment")
          description("A Comment")

          properties do
            comment(:string, "Posted comment", required: true)
            meta(:map, "Meta data of inline comments")
            is_parent(:boolean, "Parent or child comment", required: true)
            parent_id(:string, "The ParentId of the comment", required: true)
            master(:string, "The Master of the comment", required: true)
            master_id(:string, "The MasterId of the comment", required: true)

            inserted_at(:string, "When was the comment inserted", format: "ISO-8601")
            updated_at(:string, "When was the comment last updated", format: "ISO-8601")
          end

          example(%{
            comment: "a sample comment",
            is_parent: true,
            master: "instance",
            meta: %{block: "introduction", line: 12},
            master_id: "sdf15511551sdf",
            user_id: "asdf2s2dfasd2",
            organisation_id: "451s51dfsdf515",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      Comments:
        swagger_schema do
          title("Comment list")
          type(:array)
          items(Schema.ref(:Comment))
        end,
      CommentIndex:
        swagger_schema do
          properties do
            comments(Schema.ref(:Comments))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            comments: [
              %{
                comment: "a sample comment",
                meta: %{block: "introduction", line: 12},
                is_parent: true,
                master: "instance",
                master_id: "sdf15511551sdf",
                user_id: "asdf2s2dfasd2",
                organisation_id: "451s51dfsdf515",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              },
              %{
                comment: "a sample comment",
                meta: %{block: "introduction", line: 12},
                is_parent: true,
                master: "instance",
                master_id: "sdf15511551sdf",
                user_id: "asdf2s2dfasd2",
                organisation_id: "451s51dfsdf515",
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

  swagger_path :create do
    post("/comments")
    summary("Create comment")
    description("Create comment API")

    parameters do
      comment(:body, Schema.ref(:CommentRequest), "Comment to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Comment))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"master_id" => document_id, "type" => "guest"} = params) do
    current_user = conn.assigns.current_user

    with true <- Document.has_access?(current_user, document_id),
         %Comment{} = comment <- Comments.create_comment(current_user, params) do
      render(conn, "comment.json", comment: comment)
    end
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.create_comment(current_user, params) do
      Task.start(fn ->
        Notifications.comment_notification(
          current_user.id,
          comment.organisation_id,
          comment.master_id
        )
      end)

      render(conn, "comment.json", comment: comment)
    end
  end

  swagger_path :index do
    get("/comments")
    summary("Comment index")
    description("API to get the list of all comments created under a master")
    parameter(:master_id, :query, :string, "Master id")
    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:CommentIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: comments,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.comment_index(current_user, params) do
      render(conn, "index.json",
        comments: comments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :replies do
    get("/comments/replies")
    summary("Comment replies")
    description("API to get the list of replies under a comment")
    parameter(:master_id, :query, :string, "Master id")
    parameter(:comment_id, :query, :string, "comment_id")
    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:CommentIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec reply(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reply(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: comments,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.comment_replies(current_user, params) do
      render(conn, "index.json",
        comments: comments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  swagger_path :show do
    get("/comments/{id}")
    summary("Show a comment")
    description("API to show details of a comment")

    parameters do
      id(:path, :string, "comment id", required: true)
    end

    response(200, "Ok", Schema.ref(:Comment))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.show_comment(id, current_user) do
      render(conn, "comment.json", comment: comment)
    end
  end

  swagger_path :update do
    put("/comments/{id}")
    summary("Update a comment")
    description("API to update a comment")

    parameters do
      id(:path, :string, "comment id", required: true)
      comment(:body, Schema.ref(:CommentRequest), "Comment to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Comment))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.get_comment(id, current_user),
         %Comment{} = comment <- Comments.update_comment(comment, params) do
      render(conn, "comment.json", comment: comment)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/comments/{id}")
    summary("Delete a comment")
    description("API to delete a comment")

    parameters do
      id(:path, :string, "comment id", required: true)
    end

    response(200, "Ok", Schema.ref(:Comment))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Comment{} = comment <- Comments.get_comment(id, current_user),
         {:ok, %Comment{}} <- Comments.delete_comment(comment) do
      render(conn, "delete.json", comment: comment)
    end
  end
end
