defmodule WraftDocWeb.Api.V1.CollectionFormControllerTest do
  @moduledoc """
  Test module for content type role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.{Document.CollectionForm, Document.CollectionFormField, Repo}

  import WraftDoc.Factory

  @valid_attrs %{
    title: "collection form",
    description: "collection form",
    fields: %{"0" => %{name: "Title", meta: %{color: "black"}, field_type: "string"}}
  }
  @invalid_attrs %{title: nil}

  test "delete collection form", %{conn: conn} do
    user = conn.assigns.current_user
    collection_form = insert(:collection_form, organisation: user.organisation)

    count_before = CollectionForm |> Repo.all() |> length()

    conn =
      delete(
        conn,
        Routes.v1_collection_form_path(conn, :delete, collection_form.id)
      )

    assert count_before - 1 == CollectionForm |> Repo.all() |> length()
    assert json_response(conn, 200)["title"] == collection_form.title
  end

  test "create collection form with valid attrs", %{conn: conn} do
    count_before = CollectionForm |> Repo.all() |> length()
    field_count_before = CollectionFormField |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_collection_form_path(conn, :create, @valid_attrs)
      )

    field_count_after = CollectionFormField |> Repo.all() |> length()
    assert json_response(conn, 200)["collection_form"]["title"] == @valid_attrs.title
    assert count_before + 1 == CollectionForm |> Repo.all() |> length()
    assert field_count_before + 1 == field_count_after
  end

  test "create collection form with invalid attrs", %{conn: conn} do
    count_before = CollectionForm |> Repo.all() |> length()

    conn =
      post(
        conn,
        Routes.v1_collection_form_path(conn, :create, @invalid_attrs)
      )

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
    assert count_before == CollectionForm |> Repo.all() |> length()
  end

  test "update collection form with valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    collection_form = insert(:collection_form, organisation: user.organisation)

    count_before = CollectionForm |> Repo.all() |> length()

    conn =
      put(
        conn,
        Routes.v1_collection_form_path(conn, :update, collection_form.id, @valid_attrs)
      )

    assert json_response(conn, 200)["collection_form"]["title"] == @valid_attrs.title
    assert count_before == CollectionForm |> Repo.all() |> length()
  end

  test "update collection form with invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    collection_form = insert(:collection_form, organisation: user.organisation)

    count_before = CollectionForm |> Repo.all() |> length()

    conn =
      put(
        conn,
        Routes.v1_collection_form_path(conn, :update, collection_form.id, @invalid_attrs)
      )

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
    assert count_before == CollectionForm |> Repo.all() |> length()
  end

  test "show renders collection form by id", %{conn: conn} do
    user = conn.assigns.current_user
    collection_form = insert(:collection_form, organisation: user.organisation)

    conn =
      get(
        conn,
        Routes.v1_collection_form_path(conn, :show, collection_form.id)
      )

    assert json_response(conn, 200)["title"] == collection_form.title
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      get(
        conn,
        Routes.v1_collection_form_path(conn, :show, Ecto.UUID.generate())
      )

    assert json_response(conn, 400)["errors"] == "The CollectionForm id does not exist..!"
  end
end
