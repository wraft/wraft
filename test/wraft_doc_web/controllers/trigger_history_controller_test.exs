defmodule WraftDocWeb.Api.V1.TriggerHistoryControllerTest do
  @moduledoc """
  Test module for trigger history controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.{Pipelines.TriggerHistories.TriggerHistory, Repo}

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

      assert job_count_before + 1 == length(created_jobs)
      assert history_count_before + 1 == length(created_history)

      response = json_response(conn, 200)

      assert response["info"] ==
               "Trigger accepted. All the required documents in the pipeline will be created soon and will be available for you to download.!"

      assert response["trigger_id"] != nil
      assert response["pipeline_id"] == pipeline.id
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

  describe "index_by_pipeline" do
    test "index lists triggers under a pipeline with pagination", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger1 = insert(:trigger_history, state: 1, pipeline: pipeline, creator: user)
      trigger2 = insert(:trigger_history, state: 2, pipeline: pipeline, creator: user)

      conn = get(conn, Routes.v1_trigger_history_path(conn, :index_by_pipeline, pipeline.id))
      response = json_response(conn, 200)
      trigger_history_index = response["triggers"]

      trigger_uuids = Enum.map(trigger_history_index, fn x -> x["id"] end)
      trigger_states = Enum.map(trigger_history_index, fn x -> x["state"] end)
      trigger_user_ids = Enum.map(trigger_history_index, fn x -> x["creator"]["id"] end)

      assert trigger1.id in trigger_uuids
      assert trigger2.id in trigger_uuids
      assert "enqued" in trigger_states
      assert "executing" in trigger_states
      assert user.id in trigger_user_ids
      assert response["total_entries"] == 2
      assert response["total_pages"] == 1
    end
  end
end
