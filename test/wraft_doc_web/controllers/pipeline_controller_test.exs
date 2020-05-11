defmodule WraftDocWeb.Api.V1.PipelineControllerTest do
  @moduledoc """
  Test module for pipeline controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Pipeline, Document.Pipeline.Stage, Repo}

  @valid_attrs %{
    name: "Official Letter",
    api_route: "newclient.example.crm.com"
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

  test "create pipeline by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    c_type = insert(:content_type, organisation: user.organisation)
    data_temp = insert(:data_template, content_type: c_type)
    state = insert(:state, organisation: user.organisation)

    params =
      @valid_attrs
      |> Map.put(:stages, [
        %{content_type_id: c_type.uuid, data_template_id: data_temp.uuid, state_id: state.uuid}
      ])

    count_before = Pipeline |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_pipeline_path(conn, :create), params)
      |> doc(operation_id: "create_pipeline")

    content_types =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["content_type"]["name"] end)
      |> List.to_string()

    d_temps =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["data_template"]["title"] end)
      |> List.to_string()

    resp_states =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["state"]["state"] end)
      |> List.to_string()

    assert count_before + 1 == Pipeline |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert content_types =~ c_type.name
    assert d_temps =~ data_temp.title
    assert resp_states =~ state.state
  end

  test "does not create pipeline by invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    count_before = Pipeline |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_pipeline_path(conn, :create, %{}))
      |> doc(operation_id: "create_pipeline")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Pipeline |> Repo.all() |> length()
  end

  test "index lists all pipelines in current user's organisation", %{conn: conn} do
    user = conn.assigns.current_user

    p1 = insert(:pipeline, organisation: user.organisation)
    p2 = insert(:pipeline, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_pipeline_path(conn, :index))

    pipelines =
      json_response(conn, 200)["pipelines"]
      |> Enum.map(fn %{"name" => name} -> name end)
      |> List.to_string()

    assert pipelines =~ p1.name
    assert pipelines =~ p2.name
  end

  test "update pipeline on valid attributes", %{conn: conn} do
    user = conn.assigns[:current_user]

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    pipeline = insert(:pipeline, organisation: user.organisation)
    insert(:pipe_stage, pipeline: pipeline)
    c_type = insert(:content_type, organisation: user.organisation)
    data_template = insert(:data_template, content_type: c_type)
    state = insert(:state, organisation: user.organisation)


    params =
      Map.put(@valid_attrs, :stages, [
        %{
          content_type_id: c_type.uuid,
          data_template_id: data_template.uuid,
          state_id: state.uuid
        }
      ])

    conn =
      put(conn, Routes.v1_pipeline_path(conn, :update, pipeline.uuid), params)
      |> doc(operation_id: "update_pipeline")

    c_types =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["content_type"]["name"] end)
      |> List.to_string()

    data_temps =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["data_template"]["title"] end)
      |> List.to_string()

    states =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["state"]["state"] end)
      |> List.to_string()

    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert json_response(conn, 200)["api_route"] == @valid_attrs.api_route
    assert c_types =~ c_type.name
    assert data_temps =~ data_template.title
    assert states =~ state.state
  end

  test "does't update flow on invalid attrs", %{conn: conn} do
    user = conn.assigns[:current_user]
    pipeline = insert(:pipeline, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn =
      put(conn, Routes.v1_pipeline_path(conn, :update, pipeline.uuid, %{name: ""}))
      |> doc(operation_id: "update_pipeline")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
  end

  test "show renders pipeline details by id", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    pipeline = insert(:pipeline, organisation: user.organisation)

    conn = get(conn, Routes.v1_pipeline_path(conn, :show, pipeline.uuid))

    assert json_response(conn, 200)["name"] == pipeline.name
    assert json_response(conn, 200)["id"] == pipeline.uuid
  end

  test "show returns not found for non-existent ID", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_pipeline_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete pipeline by given id", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    pipeline = insert(:pipeline, organisation: user.organisation)
    count_before = Pipeline |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_pipeline_path(conn, :delete, pipeline.uuid))
    assert count_before - 1 == Pipeline |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == pipeline.name
  end

  test "delete pipe stage by given pipeline and content type ids", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    pipeline = insert(:pipeline, organisation: user.organisation)
    c_type = insert(:content_type, organisation: user.organisation)
    stage = insert(:pipe_stage, pipeline: pipeline, content_type: c_type)
    count_before = Stage |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_pipeline_path(conn, :delete_stage, pipeline.uuid, c_type.uuid))

    stages =
      json_response(conn, 200)["stages"]
      |> Enum.map(fn x -> x["content_type"]["name"] end)
      |> List.to_string()

    assert count_before - 1 == Stage |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == pipeline.name
    refute stages =~ stage.content_type.name
  end

  test "delete stage returns not found for non-existent IDs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      delete(
        conn,
        Routes.v1_pipeline_path(conn, :delete_stage, Ecto.UUID.generate(), Ecto.UUID.generate())
      )

    assert json_response(conn, 404) == "Not Found"
  end
end
