defmodule WraftDocWeb.Plug.AddActionLogTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{Repo, ActionLog}
  alias WraftDocWeb.Plug.AddActionLog

  setup %{conn: conn} do
    user = insert(:user)

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

  test "adds new log when an action is made by an authorized user", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    file = Plug.Upload.random_file!("test")

    valid_attrs = %{
      name: "Theme",
      font: "Malery",
      typescale: %{h1: "10", p: "6", h2: "8"},
      organisation_id: user.organisation_id,
      file: %Plug.Upload{filename: file, path: file}
    }

    conn = post(conn, Routes.v1_theme_path(conn, :create), valid_attrs)
    count_before = ActionLog |> Repo.all() |> length
    AddActionLog.call(conn, %{})
    all_actions = ActionLog |> Repo.all()
    last_action = all_actions |> List.last()

    assert count_before + 1 == all_actions |> length
    assert last_action.action == "create"
    assert last_action.request_path == Routes.v1_theme_path(conn, :create)
    assert last_action.user_id == user.id

    assert last_action.actor == %{
             "email" => user.email,
             "name" => user.name,
             "organisation" => %{"name" => user.organisation.name}
           }
  end

  test "adds new log when an action is made by an unauthorized user" do
    conn = build_conn()

    user = insert(:user, password: "encrypt")

    conn =
      post(conn, Routes.v1_user_path(conn, :signin, %{email: user.email, password: "encrypt"}))

    count_before = ActionLog |> Repo.all() |> length
    AddActionLog.call(conn, %{})
    all_actions = ActionLog |> Repo.all()
    last_action = all_actions |> List.last()

    assert count_before + 1 == all_actions |> length
    assert last_action.action == "signin"
    assert last_action.request_path == Routes.v1_user_path(conn, :signin)
    assert last_action.user_id == nil
    assert last_action.actor == %{}
  end
end
