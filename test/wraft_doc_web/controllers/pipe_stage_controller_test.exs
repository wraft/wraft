defmodule WraftDocWeb.Api.V1.PipeStageControllerTest do
  @moduledoc """
  Test module for pipestage controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.Document.Pipeline.Stage
  alias WraftDoc.Repo

  describe "create" do
    test "create pipe stage by valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      data_temp = insert(:data_template, content_type: c_type)

      params = %{
        content_type_id: c_type.id,
        data_template_id: data_temp.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.id), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before + 1 == Stage |> Repo.all() |> length()
      assert json_response(conn, 200)["content_type"]["name"] == c_type.name
      assert json_response(conn, 200)["content_type"]["id"] == c_type.id
      assert json_response(conn, 200)["data_template"]["title"] == data_temp.title
      assert json_response(conn, 200)["data_template"]["id"] == data_temp.id
    end

    test "does not create pipe stage and returns not found with non existent datas in attrs", %{
      conn: conn
    } do
      params = %{
        content_type_id: Ecto.UUID.generate(),
        data_template_id: Ecto.UUID.generate()
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, Ecto.UUID.generate()), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not create pipe stage and returns not found for datas from different organisation of user",
         %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      c_type = insert(:content_type)
      d_temp = insert(:data_template)

      params = %{
        content_type_id: c_type.id,
        data_template_id: d_temp.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.id), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not create pipe stage and returns not found with invalid datas", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      params = %{content_type_id: 3, data_template_id: 2}

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.id), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not create pipe stage and returns error when data template and pipeline ID are same as a previously created stage",
         %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      insert(:pipe_stage,
        pipeline: pipeline,
        content_type: c_type,
        data_template: d_temp
      )

      params = %{
        content_type_id: c_type.id,
        data_template_id: d_temp.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.id), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 422)["errors"]["data_template_id"] == ["Already added.!"]
    end
  end

  describe "update" do
    test "updates pipe stage by valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      stage = insert(:pipe_stage, pipeline: pipeline)
      c_type = insert(:content_type, organisation: organisation)
      data_temp = insert(:data_template, content_type: c_type)
      form_mapping = insert(:form_mapping, pipe_stage: stage)

      params = %{
        content_type_id: c_type.id,
        data_template_id: data_temp.id
      }

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.id), params)
        |> doc(operation_id: "update_pipe_stage")

      assert json_response(conn, 200)["id"] == stage.id
      assert json_response(conn, 200)["content_type"]["name"] == c_type.name
      assert json_response(conn, 200)["content_type"]["id"] == c_type.id
      assert json_response(conn, 200)["data_template"]["title"] == data_temp.title
      assert json_response(conn, 200)["data_template"]["id"] == data_temp.id
      assert json_response(conn, 200)["form_mapping"]["id"] == form_mapping.id
    end

    test "does not update pipe stage and returns not found with non existent datas in attrs", %{
      conn: conn
    } do
      params = %{
        content_type_id: Ecto.UUID.generate(),
        data_template_id: Ecto.UUID.generate()
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, Ecto.UUID.generate()), params)
        |> doc(operation_id: "update_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not update pipe stage and returns not found for datas from different organisation of user",
         %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      stage = insert(:pipe_stage, pipeline: pipeline)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)

      params = %{
        content_type_id: c_type.id,
        data_template_id: d_temp.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.id), params)
        |> doc(operation_id: "update_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not update pipe stage and returns not found with invalid datas", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      stage = insert(:pipe_stage, pipeline: pipeline)
      params = %{content_type_id: 3, data_template_id: 2}

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.id), params)
        |> doc(operation_id: "update_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not update pipe stage and returns error when data template and pipeline ID are same as a previously created stage",
         %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      insert(:pipe_stage,
        pipeline: pipeline,
        content_type: c_type,
        data_template: d_temp
      )

      stage = insert(:pipe_stage, pipeline: pipeline)

      params = %{
        content_type_id: c_type.id,
        data_template_id: d_temp.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.id), params)
        |> doc(operation_id: "update_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 422)["errors"]["data_template_id"] == ["Already added.!"]
    end
  end

  describe "delete" do
    test "delete pipe stage by given id", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      stage = insert(:pipe_stage, pipeline: pipeline)
      count_before = Stage |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_pipe_stage_path(conn, :delete, stage.id))

      assert count_before - 1 == Stage |> Repo.all() |> length()
      assert json_response(conn, 200)["id"] == stage.id
    end

    test "delete stage returns not found for non-existent ID", %{conn: conn} do
      conn = delete(conn, Routes.v1_pipeline_path(conn, :delete, Ecto.UUID.generate()))

      assert json_response(conn, 404) == "Not Found"
    end
  end
end
