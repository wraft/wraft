defmodule WraftDocWeb.Api.V1.DataTemplateControllerTest do
  @moduledoc """
  Test module for data template controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  alias WraftDoc.{Document.DataTemplate, Repo}

  @valid_attrs %{
    title: "Main template",
    title_template: "Offer letter of [client]",
    data: "Hi [user]",
    serialized: %{title: "Offer letter of [client]", data: "Hi [user]"}
  }
  @invalid_attrs %{title: ""}

  test "create data templates by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    content_type = insert(:content_type, creator: user, organisation: user.organisation)

    count_before = DataTemplate |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_data_template_path(conn, :create, content_type.id), @valid_attrs)
      |> doc(operation_id: "create_data_template")

    assert json_response(conn, 200)["title"] == @valid_attrs.title
    assert count_before + 1 == DataTemplate |> Repo.all() |> length()
  end

  test "does not create data templates by invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    content_type = insert(:content_type, creator: user, organisation: user.organisation)

    count_before = DataTemplate |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_data_template_path(conn, :create, content_type.id), @invalid_attrs)
      |> doc(operation_id: "create_data_template")

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
    assert count_before == DataTemplate |> Repo.all() |> length()
  end

  test "update data templates on valid attributes", %{conn: conn} do
    user = conn.assigns.current_user
    c_type = insert(:content_type, organisation: user.organisation)
    data_template = insert(:data_template, content_type: c_type)

    count_before = DataTemplate |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_data_template_path(conn, :update, data_template.id, @valid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 200)["data_template"]["title"] == @valid_attrs.title
    assert count_before == DataTemplate |> Repo.all() |> length()
  end

  test "does't update data templates for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    c_type = insert(:content_type, organisation: user.organisation)
    data_template = insert(:data_template, content_type: c_type)

    conn =
      conn
      |> put(Routes.v1_data_template_path(conn, :update, data_template.id, @invalid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
  end

  test "index lists all data templates under a content type", %{conn: conn} do
    user = conn.assigns.current_user
    content_type = insert(:content_type)

    dt1 = insert(:data_template, creator: user, content_type: content_type)
    dt2 = insert(:data_template, creator: user, content_type: content_type)

    conn = get(conn, Routes.v1_data_template_path(conn, :index, content_type.id))
    dt_index = json_response(conn, 200)["data_templates"]
    data_templates = Enum.map(dt_index, fn %{"title" => title} -> title end)
    assert List.to_string(data_templates) =~ dt1.title
    assert List.to_string(data_templates) =~ dt2.title
  end

  test "all templates lists all data templates under an organisation", %{conn: conn} do
    user = conn.assigns.current_user
    content_type = insert(:content_type)

    dt1 = insert(:data_template, creator: user, content_type: content_type)
    dt2 = insert(:data_template, creator: user, content_type: content_type)

    conn = get(conn, Routes.v1_data_template_path(conn, :all_templates))
    dt_index = json_response(conn, 200)["data_templates"]
    data_templates = Enum.map(dt_index, fn %{"title" => title} -> title end)
    assert List.to_string(data_templates) =~ dt1.title
    assert List.to_string(data_templates) =~ dt2.title
  end

  test "show renders data template details by id", %{conn: conn} do
    user = conn.assigns[:current_user]
    c_type = insert(:content_type, organisation: user.organisation)
    data_template = insert(:data_template, content_type: c_type)

    conn = get(conn, Routes.v1_data_template_path(conn, :show, data_template.id))

    assert json_response(conn, 200)["data_template"]["title"] == data_template.title
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn = get(conn, Routes.v1_data_template_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The DataTemplate id does not exist..!"
  end

  test "delete data template by given id", %{conn: conn} do
    user = conn.assigns.current_user

    c_type = insert(:content_type, organisation: user.organisation)
    data_template = insert(:data_template, content_type: c_type)
    count_before = DataTemplate |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_data_template_path(conn, :delete, data_template.id))
    assert count_before - 1 == DataTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["title"] == data_template.title
  end

  test "test bulk import job creation for data template with valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    filename = Plug.Upload.random_file!("test")
    file = %Plug.Upload{filename: filename, path: filename}

    c_type = insert(:content_type, creator: user, organisation: user.organisation)
    count_before = Oban.Job |> Repo.all() |> length()

    params = %{mapping: %{"Title" => "title"}, file: file}

    conn = post(conn, Routes.v1_data_template_path(conn, :bulk_import, c_type.id), params)

    assert count_before + 1 == Oban.Job |> Repo.all() |> length()
    assert json_response(conn, 200)["info"] == "Data Template will be created soon"
  end

  test "test bulk import job not created for data template with invalid attrs", %{conn: conn} do
    user = conn.assigns[:current_user]

    c_type = insert(:content_type, organisation: user.organisation)
    count_before = Oban.Job |> Repo.all() |> length()

    conn = post(conn, Routes.v1_data_template_path(conn, :bulk_import, c_type.id), %{})

    assert count_before == Oban.Job |> Repo.all() |> length()
    assert json_response(conn, 400)["errors"] == "Did't have enough body parameters..!"
  end

  test "error not found on user from another organisation", %{conn: conn} do
    data_template = insert(:data_template)

    conn = get(conn, Routes.v1_data_template_path(conn, :show, data_template.id))

    assert json_response(conn, 400)["errors"] == "The DataTemplate id does not exist..!"
  end
end
