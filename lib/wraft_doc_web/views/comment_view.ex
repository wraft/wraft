defmodule WraftDocWeb.Api.V1.CommentView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.ProfileView
  alias WraftDocWeb.Api.V1.UserView

  def render("comment.json", %{comment: comment}) do
    %{
      id: comment.uuid,
      comment: comment.comment,
      is_parent: comment.is_parent,
      parent_id: comment.parent_id,
      master: comment.master,
      master_id: comment.master_id,
      user: render_one(comment.user, UserView, "user.json", as: :user),
      profile: render_one(comment.user.profile, ProfileView, "base_profile.json", as: :profile),
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at
    }
  end

  def render("reply_count.json", %{reply_count: reply_count}) do
    %{reply_count: reply_count}
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

  def render("delete.json", %{comment: comment}) do
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
end
