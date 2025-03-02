defmodule WraftDocWeb.Api.V1.BlockTemplateControllerTest do
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.{BlockTemplates.BlockTemplate, Repo}

  @valid_attrs %{
    title: "a sample Title",
    body: "a sample Body",
    serialized: "a sample serialized"
  }

  @invalid_attrs %{title: ""}
  test "create block_templates by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)
    count_before = BlockTemplate |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_block_template_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_resource")

    assert count_before + 1 == BlockTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["title"] == @valid_attrs.title
  end

  test "does not create block_templates by invalid attrs", %{conn: conn} do
    count_before = BlockTemplate |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_block_template_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_resource")

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
    assert count_before == BlockTemplate |> Repo.all() |> length()
  end

  test "update block_templates on valid attributes", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)

    block_template =
      insert(:block_template, creator: user, organisation: List.first(user.owned_organisations))

    count_before = BlockTemplate |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_block_template_path(conn, :update, block_template.id, @valid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 200)["title"] == @valid_attrs.title
    assert count_before == BlockTemplate |> Repo.all() |> length()
  end

  test "does't update block_templates for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    block_template =
      insert(:block_template, creator: user, organisation: List.first(user.owned_organisations))

    conn =
      conn
      |> put(Routes.v1_block_template_path(conn, :update, block_template.id, @invalid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
  end

  test "index lists assests by current user", %{conn: conn} do
    user = conn.assigns.current_user

    insert(:profile, user: user)

    [organisation] = user.owned_organisations
    a1 = insert(:block_template, creator: user, organisation: organisation)
    a2 = insert(:block_template, creator: user, organisation: organisation)

    conn = get(conn, Routes.v1_block_template_path(conn, :index))
    block_template_index = json_response(conn, 200)["block_templates"]
    block_templates = Enum.map(block_template_index, fn %{"title" => title} -> title end)
    assert List.to_string(block_templates) =~ a1.title
    assert List.to_string(block_templates) =~ a2.title
  end

  test "show renders block_template details by id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)

    block_template =
      insert(:block_template, creator: user, organisation: List.first(user.owned_organisations))

    conn = get(conn, Routes.v1_block_template_path(conn, :show, block_template.id))

    assert json_response(conn, 200)["title"] == block_template.title
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn = get(conn, Routes.v1_block_template_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The BlockTemplate id does not exist..!"
  end

  test "delete block_template by given id", %{conn: conn} do
    user = conn.assigns.current_user
    insert(:profile, user: user)

    block_template =
      insert(:block_template, creator: user, organisation: List.first(user.owned_organisations))

    count_before = BlockTemplate |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_block_template_path(conn, :delete, block_template.id))
    assert count_before - 1 == BlockTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["title"] == block_template.title
  end

  # test "test bulk import job creation for block template with valid attrs", %{conn: conn} do
  #   filename = Plug.Upload.random_file!("test")
  #   file = %Plug.Upload{filename: filename, path: filename}

  #   count_before = Oban.Job |> Repo.all() |> length()
  #   params = %{mapping: %{"Title" => "title"}, file: file}

  #   conn = post(conn, Routes.v1_block_template_path(conn, :bulk_import), params)

  #   assert count_before + 1 == Oban.Job |> Repo.all() |> length()
  #   assert json_response(conn, 200)["info"] == "Block Template will be created soon"
  # end

  test "error not found for user from another organisation", %{conn: conn} do
    user = insert(:user)

    block_template =
      insert(:block_template, creator: user, organisation: List.first(user.owned_organisations))

    conn = get(conn, Routes.v1_block_template_path(conn, :show, block_template.id))

    assert json_response(conn, 400)["errors"] == "The BlockTemplate id does not exist..!"
  end
end
