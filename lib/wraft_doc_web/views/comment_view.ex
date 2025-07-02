defmodule WraftDocWeb.Api.V1.CommentView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.ProfileView
  alias WraftDocWeb.Api.V1.UserView

  def render("comment.json", %{comment: comment}) do
    comment
    |> comment()
    |> maybe_put_children(comment)
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
      id: comment.id,
      comment: comment.comment,
      is_parent: comment.is_parent,
      parent_id: comment.parent_id,
      master: comment.master,
      master_id: comment.master_id,
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at
    }
  end

  defp comment(comment) do
    %{
      id: comment.id,
      comment: comment.comment,
      is_parent: comment.is_parent,
      parent_id: comment.parent_id,
      master: comment.master,
      master_id: comment.master_id,
      resolved?: comment.resolved?,
      resolved_by: render_one(comment.resolver, UserView, "user.json", as: :user),
      user: render_one(comment.user, UserView, "user.json", as: :user),
      profile: render_one(comment.user.profile, ProfileView, "base_profile.json", as: :profile),
      reply_count: comment.reply_count,
      doc_version_id: comment.doc_version_id,
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at,
      meta: comment.meta
    }
  end

  defp maybe_put_children(map, %{is_parent: true, children: children}) do
    Map.put(map, :children, render_many(children, __MODULE__, "comment.json", as: :comment))
  end

  defp maybe_put_children(map, _comment), do: map
end
