defmodule WraftDocWeb.Api.V1.PipeStageControllerTest do
  @moduledoc """
  Test module for pipestage controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Pipeline.Stage, Repo}

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
    test "create pipe stage by valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      c_type = insert(:content_type, organisation: user.organisation)
      data_temp = insert(:data_template, content_type: c_type)
      state = insert(:state, organisation: user.organisation)

      params = %{
        content_type_id: c_type.id,
        data_template_id: data_temp.id,
        state_id: state.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.uuid), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before + 1 == Stage |> Repo.all() |> length()
      assert json_response(conn, 200)["content_type"]["name"] == c_type.name
      assert json_response(conn, 200)["content_type"]["id"] == c_type.id
      assert json_response(conn, 200)["data_template"]["title"] == data_temp.title
      assert json_response(conn, 200)["data_template"]["id"] == data_temp.id
      assert json_response(conn, 200)["state"]["state"] == state.state
      assert json_response(conn, 200)["state"]["id"] == state.id
    end

    test "does not create pipe stage and returns not found with non existent datas in attrs", %{
      conn: conn
    } do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      params = %{
        content_type_id: Ecto.UUID.generate(),
        data_template_id: Ecto.UUID.generate(),
        state_id: Ecto.UUID.generate()
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
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)
      state = insert(:state)

      params = %{
        content_type_id: c_type.uuid,
        data_template_id: d_temp.uuid,
        state_id: state.uuid
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.uuid), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not create pipe stage and returns not found with invalid datas", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      params = %{content_type_id: 3, data_template_id: 2, state_id: 1}

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.uuid), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not create pipe stage and returns error when content type and pipeline ID are same as a previously created stage",
         %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      c_type = insert(:content_type, organisation: user.organisation)
      d_temp = insert(:data_template, content_type: c_type)
      state = insert(:state, organisation: user.organisation)

      insert(:pipe_stage,
        pipeline: pipeline,
        content_type: c_type,
        data_template: d_temp,
        state: state
      )

      params = %{
        content_type_id: c_type.uuid,
        data_template_id: d_temp.uuid,
        state_id: state.uuid
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipe_stage_path(conn, :create, pipeline.uuid), params)
        |> doc(operation_id: "create_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 422)["errors"]["content_type_id"] == ["Already added.!"]
    end
  end

  describe "update" do
    test "updates pipe stage by valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      stage = insert(:pipe_stage, pipeline: pipeline)
      c_type = insert(:content_type, organisation: user.organisation)
      data_temp = insert(:data_template, content_type: c_type)
      state = insert(:state, organisation: user.organisation)

      params = %{
        content_type_id: c_type.id,
        data_template_id: data_temp.id,
        state_id: state.id
      }

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.uuid), params)
        |> doc(operation_id: "update_pipe_stage")

      assert json_response(conn, 200)["id"] == stage.uuid
      assert json_response(conn, 200)["content_type"]["name"] == c_type.name
      assert json_response(conn, 200)["content_type"]["id"] == c_type.id
      assert json_response(conn, 200)["data_template"]["title"] == data_temp.title
      assert json_response(conn, 200)["data_template"]["id"] == data_temp.id
      assert json_response(conn, 200)["state"]["state"] == state.state
      assert json_response(conn, 200)["state"]["id"] == state.id
    end

    test "does not update pipe stage and returns not found with non existent datas in attrs", %{
      conn: conn
    } do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      params = %{
        content_type_id: Ecto.UUID.generate(),
        data_template_id: Ecto.UUID.generate(),
        state_id: Ecto.UUID.generate()
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
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      stage = insert(:pipe_stage, pipeline: pipeline)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)
      state = insert(:state)

      params = %{
        content_type_id: c_type.id,
        data_template_id: d_temp.id,
        state_id: state.id
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
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      stage = insert(:pipe_stage, pipeline: pipeline)
      params = %{content_type_id: 3, data_template_id: 2, state_id: 1}

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.id), params)
        |> doc(operation_id: "update_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 404) == "Not Found"
    end

    test "does not update pipe stage and returns error when content type and pipeline ID are same as a previously created stage",
         %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      c_type = insert(:content_type, organisation: user.organisation)
      d_temp = insert(:data_template, content_type: c_type)
      state = insert(:state, organisation: user.organisation)

      insert(:pipe_stage,
        pipeline: pipeline,
        content_type: c_type,
        data_template: d_temp,
        state: state
      )

      stage = insert(:pipe_stage, pipeline: pipeline)

      params = %{
        content_type_id: c_type.id,
        data_template_id: d_temp.id,
        state_id: state.id
      }

      count_before = Stage |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_pipe_stage_path(conn, :update, stage.id), params)
        |> doc(operation_id: "update_pipe_stage")

      assert count_before == Stage |> Repo.all() |> length()
      assert json_response(conn, 422)["errors"]["content_type_id"] == ["Already added.!"]
    end
  end

  describe "delete" do
    test "delete pipe stage by given id", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      pipeline = insert(:pipeline, organisation: user.organisation)
      stage = insert(:pipe_stage, pipeline: pipeline)
      count_before = Stage |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_pipe_stage_path(conn, :delete, stage.id))

      assert count_before - 1 == Stage |> Repo.all() |> length()
      assert json_response(conn, 200)["id"] == stage.uuid
    end

    test "delete stage returns not found for non-existent ID", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = delete(conn, Routes.v1_pipeline_path(conn, :delete, Ecto.UUID.generate()))

      assert json_response(conn, 404) == "Not Found"
    end
  end
end
