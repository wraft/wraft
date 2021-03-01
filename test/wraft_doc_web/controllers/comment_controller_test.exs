defmodule WraftDocWeb.Api.V1.CommentControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Comment, Repo}

  @valid_attrs %{
    comment: "a sample Comment",
    is_parent: true,
    master: "Instance",
    master_id: "3adfs5sdffdas5fsdas5df"
  }

  @invalid_attrs %{comment: nil}
  setup %{conn: conn} do
    role = insert(:role, name: "admin")
    user = insert(:user, role: role)
    insert(:profile, user: user)
    user = user |> Repo.preload([:profile])

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  test "create comments by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Comment |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_comment_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_comment")

    assert count_before + 1 == Comment |> Repo.all() |> length()

    assert json_response(conn, 200)["comment"] == @valid_attrs.comment
  end

  test "does not create comments by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Comment |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_comment_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_comment")

    assert json_response(conn, 422)["errors"]["comment"] == ["can't be blank"]
    assert count_before == Comment |> Repo.all() |> length()
  end

  test "update comments on valid attributes", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    comment = insert(:comment, user: current_user, organisation: current_user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Comment |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_comment_path(conn, :update, comment.uuid, @valid_attrs))
      |> doc(operation_id: "update_comment")

    assert json_response(conn, 200)["comment"] == @valid_attrs.comment
    assert count_before == Comment |> Repo.all() |> length()
  end

  test "does't update comments for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    comment = insert(:comment, user: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      conn
      |> put(Routes.v1_comment_path(conn, :update, comment.uuid, @invalid_attrs))
      |> doc(operation_id: "update_comment")

    assert json_response(conn, 422)["errors"]["comment"] == ["can't be blank"]
  end

  test "index lists comments under a master", %{conn: conn} do
    user = conn.assigns.current_user

    a1 = insert(:comment, user: user, organisation: user.organisation)
    a2 = insert(:comment, user: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn =
      get(
        conn,
        Routes.v1_comment_path(conn, :index, page: 1, per_page: 10, master_id: a1.master_id)
      )

    comment_index = json_response(conn, 200)["comments"]
    comments = Enum.map(comment_index, fn %{"comment" => comment} -> comment end)
    assert List.to_string(comments) =~ a1.comment
    assert List.to_string(comments) =~ a2.comment
  end

  test "replies lists replies under a comment", %{conn: conn} do
    user = conn.assigns.current_user
    comment = insert(:comment, user: user, organisation: user.organisation)

    a1 =
      insert(:comment,
        user: user,
        organisation: user.organisation,
        parent_id: comment.id,
        is_parent: false
      )

    a2 =
      insert(:comment,
        user: user,
        organisation: user.organisation,
        parent_id: comment.id,
        is_parent: false
      )

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn =
      get(
        conn,
        Routes.v1_comment_path(conn, :reply, comment.uuid, %{
          page: 1,
          per_page: 10,
          master_id: a1.master_id,
          comment_id: comment.uuid
        })
      )

    comment_index = json_response(conn, 200)["comments"]
    comments = Enum.map(comment_index, fn %{"comment" => comment} -> comment end)
    assert List.to_string(comments) =~ a1.comment
    assert List.to_string(comments) =~ a2.comment
  end

  test "show renders comment details by id", %{conn: conn} do
    current_user = conn.assigns[:current_user]
    comment = insert(:comment, user: current_user, organisation: current_user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_comment_path(conn, :show, comment.uuid))

    assert json_response(conn, 200)["comment"] == comment.comment
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_comment_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete comment by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    comment = insert(:comment, user: user, organisation: user.organisation)
    count_before = Comment |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_comment_path(conn, :delete, comment.uuid))
    assert count_before - 1 == Comment |> Repo.all() |> length()
    assert json_response(conn, 200)["comment"] == comment.comment
  end

  test "error not found for user from another organisation", %{conn: conn} do
    user = insert(:user)
    comment = insert(:comment, user: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_comment_path(conn, :show, comment.uuid))

    assert json_response(conn, 404) == "Not Found"
  end
end
