defmodule WraftDocWeb.Api.V1.BlockTemplateControllerTest do
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.BlockTemplate, Repo}

  @valid_attrs %{
    title: "a sample Title",
    body: "a sample Body",
    serialized: "a sample serialized"
  }

  @invalid_attrs %{title: ""}
  setup %{conn: conn} do
    role = insert(:role, name: "admin")
    user = insert(:user, role: role)

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

  test "create block_templates by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = BlockTemplate |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_block_template_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_resource")

    assert count_before + 1 == BlockTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["title"] == @valid_attrs.title
  end

  test "does not create block_templates by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

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
    block_template = insert(:block_template, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = BlockTemplate |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_block_template_path(conn, :update, block_template.uuid, @valid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 200)["title"] == @valid_attrs.title
    assert count_before == BlockTemplate |> Repo.all() |> length()
  end

  test "does't update block_templates for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    block_template = insert(:block_template, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      conn
      |> put(Routes.v1_block_template_path(conn, :update, block_template.uuid, @invalid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 422)["errors"]["title"] == ["can't be blank"]
  end

  test "index lists assests by current user", %{conn: conn} do
    user = Repo.preload(conn.assigns.current_user, :organisation)

    a1 = insert(:block_template, organisation: user.organisation)
    a2 = insert(:block_template, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn = get(conn, Routes.v1_block_template_path(conn, :index))
    block_template_index = json_response(conn, 200)["block_templates"]
    block_templates = Enum.map(block_template_index, fn %{"title" => title} -> title end)
    assert List.to_string(block_templates) =~ a1.title
    assert List.to_string(block_templates) =~ a2.title
  end

  test "show renders block_template details by id", %{conn: conn} do
    user = conn.assigns.current_user
    block_template = insert(:block_template, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_block_template_path(conn, :show, block_template.uuid))

    assert json_response(conn, 200)["title"] == block_template.title
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_block_template_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete block_template by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    block_template = insert(:block_template, organisation: user.organisation)
    count_before = BlockTemplate |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_block_template_path(conn, :delete, block_template.uuid))
    assert count_before - 1 == BlockTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["title"] == block_template.title
  end

  test "test bulk import job creation for block template with valid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    filename = Plug.Upload.random_file!("test")
    file = %Plug.Upload{filename: filename, path: filename}

    count_before = Oban.Job |> Repo.all() |> length()
    params = %{mapping: %{"Title" => "title"}, file: file}

    conn = post(conn, Routes.v1_block_template_path(conn, :bulk_import), params)

    assert count_before + 1 == Oban.Job |> Repo.all() |> length()
    assert json_response(conn, 200)["info"] == "Block Template will be created soon"
  end

  test "error not found for user from another organisation", %{conn: conn} do
    user = insert(:user)
    block_template = insert(:block_template, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_block_template_path(conn, :show, block_template.uuid))

    assert json_response(conn, 404) == "Not Found"
  end
end
