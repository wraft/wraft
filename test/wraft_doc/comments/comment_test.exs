defmodule WraftDoc.CommentTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Comments.Comment
  @moduletag :document

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
    user = build(:user_with_organisation)

    params =
      Map.merge(@valid_attrs_for_comment, %{
        master_id: Ecto.UUID.generate(),
        user_id: user.id || Ecto.UUID.generate(),
        organisation_id: user.current_org_id || Ecto.UUID.generate()
      })

    changeset = Comment.changeset(%Comment{}, params)
    assert changeset.valid?
  end

  test "changeset with valid data for a reply" do
    user = build(:user_with_organisation)

    params =
      Map.merge(@valid_attrs_for_reply, %{
        master_id: Ecto.UUID.generate(),
        user_id: user.id || Ecto.UUID.generate(),
        organisation_id: user.current_org_id || Ecto.UUID.generate(),
        parent_id: Ecto.UUID.generate()
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
