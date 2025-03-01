defmodule WraftDocWeb.Api.V1.CollectionFormFieldControllerTest do
  @moduledoc """
  Test module for content type role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Documents.CollectionFormField
  alias WraftDoc.Repo

  import WraftDoc.Factory

  @invalid_attrs %{name: nil, collection_form_id: nil}

  test "delete collection form field", %{conn: conn} do
    user = conn.assigns.current_user

    collection_form = insert(:collection_form, organisation: List.first(user.owned_organisations))
    collection_form_field = insert(:collection_form_field, collection_form: collection_form)

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      delete(
        conn,
        Routes.v1_collection_form_field_path(
          conn,
          :delete,
          collection_form.id,
          collection_form_field.id
        )
      )

    assert count_before - 1 == CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == collection_form_field.name
  end

  test "create collection form field with valid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    collection_form = insert(:collection_form, organisation: List.first(user.owned_organisations))
    collection_form_id = collection_form.id

    params = %{
      "name" => "collection form",
      "field_type" => "string",
      "meta" => %{"color" => "blue"}
    }

    param = Map.put(params, "collection_form_id", collection_form_id)

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_collection_form_field_path(conn, :create, collection_form_id, param)
      )

    assert count_before + 1 == CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == param["name"]
    assert json_response(conn, 200)["field_type"] == param["field_type"]
    assert json_response(conn, 200)["meta"] == param["meta"]
  end

  test "create collection form field with invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    cf = insert(:collection_form, organisation: List.first(user.owned_organisations))

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_collection_form_field_path(conn, :create, cf.id, @invalid_attrs)
      )

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == CollectionFormField |> Repo.all() |> length()
  end

  test "update collection form with valid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    collection_form = insert(:collection_form, organisation: List.first(user.owned_organisations))

    # collection_form_id = collection_form.id
    # params = %{"name" => "collection form"}
    # param = Map.put(params, "collection_form_id", collection_form_id)

    collection_form_field = insert(:collection_form_field, collection_form: collection_form)

    param = %{name: "collection form field", field_type: "string"}

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      put(
        conn,
        Routes.v1_collection_form_field_path(
          conn,
          :update,
          collection_form.id,
          collection_form_field.id,
          param
        )
      )

    assert json_response(conn, 200)["name"] == param.name
    assert count_before == CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["field_type"] == param.field_type
  end

  test "update collection form with invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    collection_form = insert(:collection_form, organisation: List.first(user.owned_organisations))

    collection_form_field = insert(:collection_form_field, collection_form: collection_form)

    count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      put(
        conn,
        Routes.v1_collection_form_field_path(
          conn,
          :update,
          collection_form.id,
          collection_form_field.id,
          @invalid_attrs
        )
      )

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == CollectionFormField |> Repo.all() |> length()
  end

  test "show renders collection form field by id", %{conn: conn} do
    user = conn.assigns.current_user
    collection_form = insert(:collection_form, organisation: List.first(user.owned_organisations))
    collection_form_field = insert(:collection_form_field, collection_form: collection_form)

    conn =
      get(
        conn,
        Routes.v1_collection_form_field_path(
          conn,
          :show,
          collection_form.id,
          collection_form_field.id
        )
      )

    assert json_response(conn, 200)["name"] == collection_form_field.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    collection_form = insert(:collection_form)

    conn =
      get(
        conn,
        Routes.v1_collection_form_field_path(
          conn,
          :show,
          collection_form.id,
          Ecto.UUID.generate()
        )
      )

    assert json_response(conn, 400)["errors"] == "The CollectionFormField id does not exist..!"
  end
end
