defmodule WraftDocWeb.Plug.AddActionLogTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{ActionLog, Repo}
  alias WraftDocWeb.Plug.AddActionLog

  test "adds new log when an action is made by an authorized user" do
    user = insert(:user)
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> assign(:current_user, user)
      |> put_req_header("user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4)")
      |> put_private(:phoenix_action, :test)
      |> Map.put(:request_path, "/test")
      |> Map.put(:method, "POST")
      |> Map.put(:params, %{test: "test"})

    count_before = ActionLog |> Repo.all() |> length
    AddActionLog.call(conn, %{})
    all_actions = Repo.all(ActionLog)
    last_action = List.last(all_actions)

    assert count_before + 1 == length(all_actions)
    assert last_action.action == "test"

    assert last_action.request_path == "/test"
    assert last_action.user_id == user.id

    assert last_action.actor == %{
             "email" => user.email,
             "name" => user.name,
             "organisation" => %{"name" => user.organisation.name}
           }
  end

  # test "adds new log when an action is made by an unauthorized user" do
  #   conn =
  #     build_conn()
  #     |> put_req_header("user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4)")
  #     |> put_private(:phoenix_action, :test)
  #     |> Map.put(:params, %{})

  #   count_before = ActionLog |> Repo.all() |> length
  #   AddActionLog.call(conn, %{})
  #   all_actions = Repo.all(ActionLog)
  #   last_action = List.last(all_actions)

  #   assert count_before + 1 == length(all_actions)
  #   assert last_action.action == "test"
  #   assert last_action.request_path == "/"
  #   assert last_action.user_id == nil
  #   assert last_action.actor == %{}
  # end
end
