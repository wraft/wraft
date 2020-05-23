defmodule WraftDocWeb.Api.V1.TriggerHistoryControllerTest do
  @moduledoc """
  Test module for trigger history controller
  """
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Document.Pipeline.TriggerHistory}

  @valid_attrs %{
    data: %{name: "John Doe"}
  }

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

  describe "create" do
    test "creates trigger history and pipeline run job with valid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      job_count_before = Oban.Job |> Repo.all() |> length()
      history_count_before = TriggerHistory |> Repo.all() |> length()

      conn =
        post(conn, Routes.v1_trigger_history_path(conn, :create, pipeline.uuid), @valid_attrs)
        |> doc(operation_id: "create_trigger_history")

      created_jobs = Oban.Job |> Repo.all()
      created_history = TriggerHistory |> Repo.all()

      data =
        created_history
        |> Enum.map(fn x -> x.data end)
        |> List.last()

      data = for {key, val} <- data, into: %{}, do: {String.to_atom(key), val}

      assert job_count_before + 1 == created_jobs |> length()
      assert history_count_before + 1 == created_history |> length()
      assert data == @valid_attrs.data

      assert json_response(conn, 200)["info"] ==
               "Trigger accepted. All the required documents in the pipeline will be created soon and will be available for you to download.!"
    end

    test "does not create trigger history with invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      job_count_before = Oban.Job |> Repo.all() |> length()
      history_count_before = TriggerHistory |> Repo.all() |> length()

      conn =
        post(conn, Routes.v1_trigger_history_path(conn, :create, pipeline.uuid), %{
          data: "wrong meta"
        })
        |> doc(operation_id: "create_trigger_history")

      assert job_count_before == Oban.Job |> Repo.all() |> length()
      assert history_count_before == TriggerHistory |> Repo.all() |> length()
      assert json_response(conn, 422)["errors"]["data"] == ["is invalid"]
    end

    test "does not create trigger history when pipeline belongs to different organisation", %{
      conn: conn
    } do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline)
      job_count_before = Oban.Job |> Repo.all() |> length()
      history_count_before = TriggerHistory |> Repo.all() |> length()

      conn =
        post(conn, Routes.v1_trigger_history_path(conn, :create, pipeline.uuid), @valid_attrs)
        |> doc(operation_id: "create_trigger_history")

      assert job_count_before == Oban.Job |> Repo.all() |> length()
      assert history_count_before == TriggerHistory |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "index/2" do
    test "index lists triggers under a pipeline with pagination", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: user.organisation)
      trigger1 = insert(:trigger_history, state: 1, pipeline: pipeline, creator: user)
      trigger2 = insert(:trigger_history, state: 2, pipeline: pipeline, creator: user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_trigger_history_path(conn, :index, pipeline.uuid))
      trigger_history_index = json_response(conn, 200)["triggers"]
      trigger_uuids = Enum.map(trigger_history_index, fn x -> x["id"] end) |> List.to_string()
      trigger_states = Enum.map(trigger_history_index, fn x -> x["state"] end) |> List.to_string()

      trigger_user_uuid =
        Enum.map(trigger_history_index, fn x -> x["creator"]["id"] end) |> List.to_string()

      assert trigger_uuids =~ trigger1.uuid
      assert trigger_uuids =~ trigger2.uuid
      assert trigger_states =~ "enqued"
      assert trigger_states =~ "executing"
      assert trigger_user_uuid =~ user.uuid
      assert json_response(conn, 200)["total_entries"] == 2
      assert json_response(conn, 200)["total_pages"] == 1
    end
  end
end
