defmodule WraftDocWeb.Api.V1.PipelineControllerTest do
  @moduledoc """
  Test module for pipeline controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  alias WraftDoc.{Document.Pipeline, Repo}

  @valid_attrs %{
    name: "Official Letter",
    source: "WraftForms",
    source_id: "33a7e44c-0999-4d79-8ef9-698796101585",
    api_route: "newclient.example.crm.com"
  }

  describe "create/2" do
    test "create pipeline by valid attrrs", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      c_type = insert(:content_type, organisation: organisation)
      insert(:content_type_field, content_type: c_type)
      data_temp = insert(:data_template, content_type: c_type)
      form = insert(:form, organisation: organisation, creator: user)

      params =
        Map.merge(@valid_attrs, %{
          stages: [%{content_type_id: c_type.id, data_template_id: data_temp.id}],
          source_id: "#{form.id}"
        })

      count_before = Pipeline |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipeline_path(conn, :create), params)
        |> doc(operation_id: "create_pipeline")

      content_types =
        conn
        |> json_response(200)
        |> get_in(["stages"])
        |> Enum.map(fn x -> x["content_type"]["name"] end)
        |> List.to_string()

      d_temps =
        conn
        |> json_response(200)
        |> get_in(["stages"])
        |> Enum.map(fn x -> x["data_template"]["title"] end)
        |> List.to_string()

      assert count_before + 1 == Pipeline |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert json_response(conn, 200)["api_route"] == @valid_attrs.api_route
      assert json_response(conn, 200)["source"] == @valid_attrs.source
      assert json_response(conn, 200)["source_id"] == params.source_id
      assert content_types =~ c_type.name
      assert d_temps =~ data_temp.title
    end

    test "does not create pipeline by invalid attrs", %{conn: conn} do
      count_before = Pipeline |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_pipeline_path(conn, :create, %{}))
        |> doc(operation_id: "create_pipeline")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert count_before == Pipeline |> Repo.all() |> length()
    end
  end

  describe "index/2" do
    test "index lists all pipelines in current user's organisation", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      p1 = insert(:pipeline, organisation: organisation)
      p2 = insert(:pipeline, organisation: organisation)

      conn = get(conn, Routes.v1_pipeline_path(conn, :index))

      pipelines =
        conn
        |> json_response(200)
        |> get_in(["pipelines"])
        |> Enum.map(fn %{"name" => name} -> name end)
        |> List.to_string()

      assert pipelines =~ p1.name
      assert pipelines =~ p2.name
    end
  end

  describe "update/2" do
    test "update pipeline on valid attributes", %{conn: conn} do
      user = conn.assigns[:current_user]
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      insert(:pipe_stage, pipeline: pipeline)
      c_type = insert(:content_type, organisation: organisation)
      data_template = insert(:data_template, content_type: c_type)
      insert(:pipe_stage, pipeline: pipeline, data_template: data_template, content_type: c_type)

      params =
        Map.put(@valid_attrs, :stages, [
          %{
            content_type_id: c_type.id,
            data_template_id: data_template.id
          }
        ])

      conn =
        conn
        |> put(Routes.v1_pipeline_path(conn, :update, pipeline.id), params)
        |> doc(operation_id: "update_pipeline")

      c_types =
        conn
        |> json_response(200)
        |> get_in(["stages"])
        |> Enum.map(fn x -> x["content_type"]["name"] end)
        |> List.to_string()

      data_temps =
        conn
        |> json_response(200)
        |> get_in(["stages"])
        |> Enum.map(fn x -> x["data_template"]["title"] end)
        |> List.to_string()

      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert json_response(conn, 200)["api_route"] == @valid_attrs.api_route
      assert json_response(conn, 200)["source"] == @valid_attrs.source
      assert json_response(conn, 200)["source_id"] == @valid_attrs.source_id
      assert c_types =~ c_type.name
      assert data_temps =~ data_template.title
    end

    test "does't update flow on invalid attrs", %{conn: conn} do
      user = conn.assigns[:current_user]
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))

      conn =
        conn
        |> put(Routes.v1_pipeline_path(conn, :update, pipeline.id, %{name: ""}))
        |> doc(operation_id: "update_pipeline")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "show/2" do
    test "show renders pipeline details by id", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      c_type = insert(:content_type)
      insert(:content_type_field, content_type: c_type)
      pipe_stage = insert(:pipe_stage, pipeline: pipeline, content_type: c_type)
      form_mapping = insert(:form_mapping, pipe_stage: pipe_stage)
      conn = get(conn, Routes.v1_pipeline_path(conn, :show, pipeline.id))

      assert json_response(conn, 200)["name"] == pipeline.name
      assert json_response(conn, 200)["api_route"] == pipeline.api_route
      assert json_response(conn, 200)["source"] == pipeline.source
      assert json_response(conn, 200)["source_id"] == pipeline.source_id
      assert json_response(conn, 200)["id"] == pipeline.id

      assert List.first(json_response(conn, 200)["stages"])["form_mapping"]["id"] ==
               form_mapping.id
    end

    test "show returns not found for non-existent ID", %{conn: conn} do
      conn = get(conn, Routes.v1_pipeline_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "delete/2" do
    test "delete pipeline by given id", %{conn: conn} do
      user = conn.assigns.current_user
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      count_before = Pipeline |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_pipeline_path(conn, :delete, pipeline.id))
      assert count_before - 1 == Pipeline |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == pipeline.name
    end
  end
end
