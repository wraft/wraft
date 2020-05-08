defmodule WraftDocWeb.Api.V1.PipelineControllerTest do
  @moduledoc """
  Test module for pipeline controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Pipeline, Repo}

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

    c_type1 = insert(:content_type)
    c_type2 = insert(:content_type)

    params = @valid_attrs |> Map.put(:content_types, [c_type1.uuid, c_type2.uuid])
    count_before = Pipeline |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_pipeline_path(conn, :create, params))
      |> doc(operation_id: "create_pipeline")

    content_types =
      json_response(conn, 200)["content_types"]
      |> Enum.map(fn x -> x["name"] end)
      |> List.to_string()

    assert count_before + 1 == Pipeline |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert content_types =~ c_type1.name
    assert content_types =~ c_type2.name
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
end
