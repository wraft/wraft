defmodule WraftDocWeb.Api.V1.OrganisationFieldControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Document
  alias WraftDoc.{Document.OrganisationField, Repo}
  import WraftDoc.Factory

  @create_attrs %{
    description: "some description",
    meta: %{},
    name: "some name"
  }
  @update_attrs %{
    description: "some updated description",
    meta: %{},
    name: "some updated name"
  }
  @invalid_attrs %{description: nil, meta: nil, name: nil, id: nil}

  setup %{conn: conn} do
    user = insert(:user)
    insert(:membership, organisation: user.organisation)

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

  describe "index" do
    test "lists all organisation_field under that organisation", %{conn: conn} do
      %{organisation: org} = conn.assigns.current_user

      of1 = insert(:organisation_field, organisation: org)

      of2 = insert(:organisation_field, organisation: org)
      of3 = insert(:organisation_field)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_organisation_field_path(conn, :index, %{page: 1}))

      assert json_response(conn, 200)["organisation_fields"]
             |> Enum.map(fn x -> x["name"] end)
             |> List.to_string() =~ of1.name

      assert json_response(conn, 200)["organisation_fields"]
             |> Enum.map(fn x -> x["name"] end)
             |> List.to_string() =~ of2.name

      refute json_response(conn, 200)["organisation_fields"]
             |> Enum.map(fn x -> x["name"] end)
             |> List.to_string() =~ of3.name
    end
  end

  describe "create organisation_field" do
    test "renders organisation_field when data is valid", %{conn: conn} do
      user = conn.assigns.current_user
      field_type = insert(:field_type, creator: user)
      params = Map.put(@create_attrs, :field_type_id, field_type.id)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      count_before = OrganisationField |> Repo.all() |> length()
      conn = post(conn, Routes.v1_organisation_field_path(conn, :create), params)
      count_after = OrganisationField |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == @create_attrs.name

      assert count_before + 1 == count_after
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      field_type = insert(:field_type, creator: user)
      params = Map.put(@invalid_attrs, :field_type_id, field_type.id)
      count_before = OrganisationField |> Repo.all() |> length()
      conn = post(conn, Routes.v1_organisation_field_path(conn, :create), params)

      count_after = OrganisationField |> Repo.all() |> length()
      assert count_after == count_before
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update organisation_field" do
    test "renders organisation_field when data is valid", %{conn: conn} do
      user = conn.assigns.current_user
      organisation_field = insert(:organisation_field, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn =
        put(
          conn,
          Routes.v1_organisation_field_path(conn, :update, organisation_field.id),
          @update_attrs
        )

      assert json_response(conn, 200)["name"] == @update_attrs.name
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = conn.assigns.current_user
      organisation_field = insert(:organisation_field, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn =
        put(
          conn,
          Routes.v1_organisation_field_path(conn, :update, organisation_field.id),
          @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete organisation_field" do
    test "deletes chosen organisation_field", %{conn: conn} do
      user = conn.assigns.current_user
      organisation_field = insert(:organisation_field, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      count_before = OrganisationField |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_organisation_field_path(conn, :delete, organisation_field.id))

      count_after = OrganisationField |> Repo.all() |> length()
      assert count_before - 1 == count_after
      assert response(conn, 200)
    end
  end
end
