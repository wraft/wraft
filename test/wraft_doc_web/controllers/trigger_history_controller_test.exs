defmodule WraftDocWeb.Api.V1.TriggerHistoryControllerTest do
  @moduledoc """
  Test module for trigger history controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.{Document.Pipeline.TriggerHistory, Repo}

  @valid_attrs %{
    data: %{name: "John Doe"}
  }

  describe "create" do
    test "creates trigger history and pipeline run job with valid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      job_count_before = Oban.Job |> Repo.all() |> length()
      history_count_before = TriggerHistory |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_trigger_history_path(conn, :create, pipeline.id), @valid_attrs)
        |> doc(operation_id: "create_trigger_history")

      created_jobs = Repo.all(Oban.Job)
      created_history = Repo.all(TriggerHistory)

      data =
        created_history
        |> Enum.map(fn x -> x.data end)
        |> List.last()

      data = for {key, val} <- data, into: %{}, do: {String.to_atom(key), val}

      assert job_count_before + 1 == length(created_jobs)
      assert history_count_before + 1 == length(created_history)
      assert data == @valid_attrs.data

      assert json_response(conn, 200)["info"] ==
               "Trigger accepted. All the required documents in the pipeline will be created soon and will be available for you to download.!"
    end

    test "does not create trigger history with invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      job_count_before = Oban.Job |> Repo.all() |> length()
      history_count_before = TriggerHistory |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_trigger_history_path(conn, :create, pipeline.id), %{
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
      pipeline = insert(:pipeline)
      job_count_before = Oban.Job |> Repo.all() |> length()
      history_count_before = TriggerHistory |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_trigger_history_path(conn, :create, pipeline.id), @valid_attrs)
        |> doc(operation_id: "create_trigger_history")

      assert job_count_before == Oban.Job |> Repo.all() |> length()
      assert history_count_before == TriggerHistory |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "index_by_pipeline/2" do
    test "index lists triggers under a pipeline with pagination", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger1 = insert(:trigger_history, state: 1, pipeline: pipeline, creator: user)
      trigger2 = insert(:trigger_history, state: 2, pipeline: pipeline, creator: user)

      conn = get(conn, Routes.v1_trigger_history_path(conn, :index_by_pipeline, pipeline.id))
      trigger_history_index = json_response(conn, 200)["triggers"]
      trigger_uuids = trigger_history_index |> Enum.map(fn x -> x["id"] end) |> List.to_string()

      trigger_states =
        trigger_history_index |> Enum.map(fn x -> x["state"] end) |> List.to_string()

      trigger_user_uuid =
        trigger_history_index |> Enum.map(fn x -> x["creator"]["id"] end) |> List.to_string()

      assert trigger_uuids =~ trigger1.id
      assert trigger_uuids =~ trigger2.id
      assert trigger_states =~ "enqued"
      assert trigger_states =~ "executing"
      assert trigger_user_uuid =~ user.id
      assert json_response(conn, 200)["total_entries"] == 2
      assert json_response(conn, 200)["total_pages"] == 1
    end
  end
end
