defmodule WraftDocWeb.Api.V1.CollectionFormFieldControllerTest do
  @moduledoc """
  Test module for content type role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Document.CollectionFormField
  alias WraftDoc.Repo

  import WraftDoc.Factory

  @valid_attrs %{name: "collection form", description: "collection form"}
  @invalid_attrs %{name: nil, collection_form_id: nil}

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

  test "delete collection form field", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    collection_form_field = insert(:collection_form_field)

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      delete(
        conn,
        Routes.v1_collection_form_field_path(conn, :delete, collection_form_field.id)
      )

    assert count_before - 1 == CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == collection_form_field.name
  end

  test "create collection form field with valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    collection_form = insert(:collection_form)
    collection_form_id = collection_form.id
    params = %{"name" => "collection form", "field_type" => "string"}
    param = Map.put(params, "collection_form_id", collection_form_id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_collection_form_field_path(conn, :create, param)
      )

    assert count_before + 1 == CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == param["name"]
    assert json_response(conn, 200)["field_type"] == param["field_type"]
  end

  test "create collection form field with invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_collection_form_field_path(conn, :create, @invalid_attrs)
      )

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == CollectionFormField |> Repo.all() |> length()
  end

  test "update collection form with valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    # collection_form = insert(:collection_form)
    # collection_form_id = collection_form.id
    # params = %{"name" => "collection form"}
    # param = Map.put(params, "collection_form_id", collection_form_id)

    collection_form_field = insert(:collection_form_field)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user

    param = %{name: "collection form field", field_type: "string"}

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      put(
        conn,
        Routes.v1_collection_form_field_path(conn, :update, collection_form_field.id, param)
      )

    assert json_response(conn, 200)["name"] == param.name
    assert count_before == CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["field_type"] == param.field_type
  end

  test "update collection form with invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    collection_form_field = insert(:collection_form_field)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      put(
        conn,
        Routes.v1_collection_form_field_path(
          conn,
          :update,
          collection_form_field.id,
          @invalid_attrs
        )
      )

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == CollectionFormField |> Repo.all() |> length()
  end

  test "show renders collection form field by id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    collection_form_field = insert(:collection_form_field)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user

    conn =
      get(
        conn,
        Routes.v1_collection_form_field_path(conn, :show, collection_form_field.id)
      )

    assert json_response(conn, 200)["name"] == collection_form_field.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    collection_form_field = insert(:collection_form_field)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user

    conn =
      get(
        conn,
        Routes.v1_collection_form_field_path(conn, :show, Ecto.UUID.generate())
      )

    assert json_response(conn, 400)["errors"] == "The CollectionFormField id does not exist..!"
  end
end
