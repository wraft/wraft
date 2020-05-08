defmodule WraftDoc.Document.CommentTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.Comment

  @valid_attrs_for_comment %{
    comment: "a sample comment",
    is_parent: true,
    parent_id: nil,
    master: "instance"
  }

  @valid_attrs_for_reply %{
    comment: "a sample reply",
    is_parent: false,
    master: "instance"
  }

  @invalid_attrs %{comment: ""}

  test "changeset with valid data for a comment" do
    %{id: master_id} = insert(:instance)
    %{id: user_id, organisation_id: org_id} = insert(:user)

    params =
      @valid_attrs_for_comment
      |> Map.merge(%{master_id: "#{master_id}", user_id: user_id, organisation_id: org_id})

    changeset = Comment.changeset(%Comment{}, params)
    assert changeset.valid?
  end

  test "changeset with valid data for a reply" do
    %{id: id} = insert(:comment)
    %{id: master_id} = insert(:instance)
    %{id: user_id, organisation_id: org_id} = insert(:user)

    params =
      @valid_attrs_for_reply
      |> Map.merge(%{
        master_id: "#{master_id}",
        user_id: user_id,
        organisation_id: org_id,
        parent_id: id
      })

    changeset = Comment.changeset(%Comment{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Comment.changeset(%Comment{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "reply count changeset with valid params" do
    params = %{reply_count: 2}
    changeset = Comment.reply_count_changeset(%Comment{}, params)
    assert changeset.valid?
  end

  test "reply count changeset with invalid params" do
    params = %{reply_count: ""}
    changeset = Comment.reply_count_changeset(%Comment{}, params)
    refute changeset.valid?
  end
end
