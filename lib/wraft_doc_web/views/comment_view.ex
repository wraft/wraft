defmodule WraftDocWeb.Api.V1.CommentView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("comment.json", %{comment: comment}) do
    %{
      id: comment.uuid,
      comment: comment.comment,
      is_parent: comment.is_parent,
      parent_id: comment.parent_id,
      master: comment.master,
      master_id: comment.master_id,
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at
    }
  end

  def render("replay_count.json", %{replay_count: replay_count}) do
    %{replay_count: replay_count}
  end

  def render("index.json", %{
        comments: comments,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      comments: render_many(comments, CommentView, "comment.json", as: :comment),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
