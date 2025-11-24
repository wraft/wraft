defmodule WraftDocWeb.Api.V1.ContentTypeControllerTest do
  @moduledoc """
  Test module for content type controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Repo

  @fields [
    %{
      name: "employee_name",
      meta: %{},
      description: "Name of the employee"
    },
    %{
      name: "position",
      meta: %{},
      description: "Position of the employee"
    }
  ]

  @valid_attrs %{
    name: "Offer letter",
    description: "An offer letter",
    prefix: "OFFLET",
    color: "#ffffff"
  }

  @invalid_attrs %{"name" => ""}

  describe "create/2" do
    test "create content types by valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:profile, user: user)
      [organisation] = user.owned_organisations

      %{id: flow_id} = insert(:flow, organisation: organisation)
      %{id: layout_id} = insert(:layout, organisation: organisation)
      %{id: theme_id} = theme = insert(:theme, organisation: organisation)

      asset = insert(:asset, type: "theme", organisation: organisation)
      insert(:theme_asset, theme: theme, asset: asset)

      params =
        Map.merge(setup_params(), %{flow_id: flow_id, layout_id: layout_id, theme_id: theme_id})

      response =
        conn
        |> post(Routes.v1_content_type_path(conn, :create), params)
        |> doc(operation_id: "create_content_type")
        |> json_response(200)

      assert response["name"] == @valid_attrs.name
      assert response["description"] == @valid_attrs.description
      assert response["theme"]["id"] == theme.id

      assert Enum.map(
               response["theme"]["assets"],
               &%{
                 id: &1["id"],
                 name: &1["name"],
                 type: &1["type"]
               }
             ) == [%{id: asset.id, name: asset.name, type: "theme"}]

      assert Enum.map(
               response["fields"],
               &%{
                 name: &1["name"],
                 meta: &1["meta"],
                 description: &1["description"],
                 field_type_id: &1["field_type"]["id"]
               }
             ) == params.fields
    end

    # FIXME
    test "does not create content types by invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      %{id: flow_id} = insert(:flow, organisation: organisation)
      %{id: layout_id} = insert(:layout, organisation: organisation)
      %{id: theme_id} = insert(:theme, organisation: organisation)

      params =
        Map.merge(@invalid_attrs, %{
          "flow_id" => flow_id,
          "layout_id" => layout_id,
          "theme_id" => theme_id
        })

      conn =
        conn
        |> post(Routes.v1_content_type_path(conn, :create), params)
        |> doc(operation_id: "create_content_type")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end

    test "does not create content type if flow does not belong to user's current organisation", %{
      conn: conn
    } do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations

      %{id: flow_id} = insert(:flow)
      %{id: layout_id} = insert(:layout, organisation: organisation)
      %{id: theme_id} = insert(:theme, organisation: organisation)

      params =
        Map.merge(@valid_attrs, %{flow_id: flow_id, layout_id: layout_id, theme_id: theme_id})

      conn =
        conn
        |> post(Routes.v1_content_type_path(conn, :create), params)
        |> doc(operation_id: "create_content_type")

      assert json_response(conn, 400)["errors"] == "The Flow id does not exist..!"
    end

    test "does not create content type if layout does not belong to user's current organisation",
         %{
           conn: conn
         } do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations

      %{id: layout_id} = insert(:layout)
      %{id: flow_id} = insert(:flow, organisation: organisation)
      %{id: theme_id} = insert(:theme, organisation: organisation)

      params =
        Map.merge(@valid_attrs, %{flow_id: flow_id, layout_id: layout_id, theme_id: theme_id})

      conn =
        conn
        |> post(Routes.v1_content_type_path(conn, :create), params)
        |> doc(operation_id: "create_content_type")

      assert json_response(conn, 400)["errors"] == "The Layout id does not exist..!"
    end

    test "does not create content type if theme does not belong to user's current organisation",
         %{
           conn: conn
         } do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations

      %{id: theme_id} = insert(:theme)
      %{id: layout_id} = insert(:layout, organisation: organisation)
      %{id: flow_id} = insert(:flow, organisation: organisation)

      params =
        Map.merge(@valid_attrs, %{flow_id: flow_id, layout_id: layout_id, theme_id: theme_id})

      conn =
        conn
        |> post(Routes.v1_content_type_path(conn, :create), params)
        |> doc(operation_id: "create_content_type")

      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "update/2" do
    test "update content type on valid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, creator: user, organisation: organisation)

      %{id: flow_id} = insert(:flow, organisation: organisation)
      %{id: layout_id} = insert(:layout, organisation: organisation)
      %{id: theme_id} = insert(:theme, organisation: organisation)

      params =
        Map.merge(setup_params(), %{flow_id: flow_id, layout_id: layout_id, theme_id: theme_id})

      Enum.map(params.fields, fn field ->
        insert(:content_type_field, content_type: content_type, field: field)
      end)

      response =
        conn
        |> put(Routes.v1_content_type_path(conn, :update, content_type.id), params)
        |> doc(operation_id: "update_content_type")
        |> json_response(200)

      assert response["content_type"]["id"] == content_type.id
      assert response["content_type"]["name"] == @valid_attrs.name

      assert Enum.sort(
               Enum.map(
                 response["content_type"]["fields"],
                 &%{
                   name: &1["name"],
                   meta: &1["meta"],
                   description: &1["description"],
                   field_type_id: &1["field_type"]["id"]
                 }
               )
             ) == Enum.sort(params.fields)
    end

    test "does't update content types for invalid attrs", %{conn: conn} do
      user = conn.assigns[:current_user]
      organisation = List.first(user.owned_organisations)

      content_type = insert(:content_type, creator: user, organisation: organisation)
      layout = insert(:layout, organisation: organisation)

      # Merge the valid layout_id with your invalid attrs
      params = Map.merge(@invalid_attrs, %{"layout_id" => layout.id})

      conn =
        conn
        |> put(Routes.v1_content_type_path(conn, :update, content_type.id), params)
        |> doc(operation_id: "update_content_type")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "index/2" do
    test "index lists content type by current user", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:profile, user: user)
      [organisation] = user.owned_organisations
      ct1 = insert(:content_type, creator: user, organisation: organisation)
      ct2 = insert(:content_type, creator: user, organisation: organisation)

      conn = get(conn, Routes.v1_content_type_path(conn, :index))
      ct_index = json_response(conn, 200)["content_types"]
      content_type = Enum.map(ct_index, fn %{"name" => name} -> name end)
      assert List.to_string(content_type) =~ ct1.name
      assert List.to_string(content_type) =~ ct2.name
    end
  end

  describe "show/2" do
    test "show renders content type details by id", %{conn: conn} do
      user = conn.assigns.current_user

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      conn = get(conn, Routes.v1_content_type_path(conn, :show, content_type.id))

      assert json_response(conn, 200)["content_type"]["name"] == content_type.name
    end

    test "error not found for users from another organisation", %{conn: conn} do
      content_type = insert(:content_type)

      conn = get(conn, Routes.v1_content_type_path(conn, :show, content_type.id))

      assert json_response(conn, 400)["errors"] == "The ContentType id does not exist..!"
    end

    test "error not found for id does not exists", %{conn: conn} do
      conn = get(conn, Routes.v1_asset_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 400)["errors"] == "The id does not exist..!"
    end
  end

  describe "delete/2" do
    test "delete content type by given id", %{conn: conn} do
      user = conn.assigns.current_user

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      count_before = ContentType |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_content_type_path(conn, :delete, content_type.id))
      assert count_before - 1 == ContentType |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == content_type.name
    end
  end

  defp setup_params do
    field_type = Repo.get_by(FieldType, name: "String")

    fields = Enum.map(@fields, &Map.put(&1, :field_type_id, field_type.id))
    Map.put(@valid_attrs, :fields, fields)
  end
end
