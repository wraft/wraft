defmodule WraftDoc.LayoutsTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.Layouts
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Repo

  setup :verify_on_exit!

  @valid_layout_attrs %{
    "name" => "layout name",
    "description" => "layout description",
    "width" => 25.0,
    "height" => 44.0,
    "unit" => "cm",
    "slug" => "layout slug"
    # "engine_id" => "00f47af7-6db5-4b93-bafb-99d453929aea"
  }
  @valid_asset_attrs %{
    "name" => "asset name",
    "type" => "layout",
    "file" => %Plug.Upload{
      content_type: "application/pdf",
      filename: "invoice.pdf",
      path: "test/helper/invoice.pdf"
    }
  }

  @invalid_instance_attrs %{raw: nil}
  @invalid_attrs %{}

  @data [
    %{"label" => "January", "value" => 10},
    %{"label" => "February", "value" => 20},
    %{"label" => "March", "value" => 5},
    %{"label" => "April", "value" => 60},
    %{"label" => "May", "value" => 80},
    %{"label" => "June", "value" => 70},
    %{"label" => "Julay", "value" => 90}
  ]
  @update_valid_attrs %{
    "btype" => "gantt",
    "file_url" => "/usr/local/hoem/filex.svg",
    "api_route" => "http://localhost:4000",
    "dataset" => %{
      "backgroundColor" => "transparent",
      "data" => @data,
      "format" => "svg",
      "height" => 512,
      "type" => "pie",
      "width" => 512
    },
    "endpoint" => "blocks_api",
    "name" => "Farming"
  }

  describe "create_layout/3" do
    test "create layout on valid attributes" do
      user = insert(:user_with_organisation)
      engine = insert(:engine)
      engine_id = engine.id

      params = %{
        "name" => "layout name",
        "description" => "layout description",
        "width" => 25.0,
        "height" => 44.0,
        "unit" => "cm",
        "slug" => "layout slug"
        # "engine_id" => "00f47af7-6db5-4b93-bafb-99d453929aea"
      }

      params = Map.merge(params, %{"engine_id" => engine_id})

      count_before =
        Layout
        |> Repo.all()
        |> length()

      {:ok, layout} = Layouts.create_layout(user, engine, params)

      assert count_before + 1 ==
               Layout
               |> Repo.all()
               |> length()

      assert layout.layout.name == @valid_layout_attrs["name"]
      assert layout.layout.description == @valid_layout_attrs["description"]
      assert layout.layout.width == @valid_layout_attrs["width"]
      assert layout.layout.height == @valid_layout_attrs["height"]
      assert layout.layout.unit == @valid_layout_attrs["unit"]
      assert layout.layout.slug == @valid_layout_attrs["slug"]
    end

    test "create layout on invalid attrs" do
      user = insert(:user_with_organisation)

      count_before =
        Layout
        |> Repo.all()
        |> length()

      engine = insert(:engine)
      {:error, changeset} = Layouts.create_layout(user, engine, @invalid_attrs)

      count_after =
        Layout
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               name: ["can't be blank"],
               description: ["can't be blank"]
             } == errors_on(changeset)
    end

    test "return error if layout with same name exists" do
      user = insert(:user_with_organisation)
      engine = insert(:engine)
      engine_id = engine.id

      insert(:layout,
        name: "Layout Name",
        creator: user,
        organisation: List.first(user.owned_organisations)
      )

      params = %{
        "name" => "Layout Name",
        "description" => "layout description",
        "width" => 25.0,
        "height" => 44.0,
        "unit" => "cm",
        "slug" => "layout slug"
      }

      params = Map.merge(params, %{"engine_id" => engine_id})

      {:error, changeset} = Layouts.create_layout(user, engine, params)

      assert %{
               name: ["Layout with the same name exists. Use another name.!"]
             } == errors_on(changeset)
    end
  end

  describe "show_layout/2" do
    test "show layout shows the layout data and preloads engine creator assets data" do
      user = insert(:user_with_organisation)
      engine = insert(:engine)

      layout =
        insert(
          :layout,
          creator: user,
          engine: engine,
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      s_layout = Layouts.show_layout(layout.id, user)

      assert s_layout.name == layout.name
      assert s_layout.description == layout.description
      assert s_layout.creator.name == user.name
      assert s_layout.engine.name == engine.name
    end

    test "returns nil with non-existent UUIDs" do
      user = insert(:user_with_organisation)
      s_layout = Layouts.show_layout(Ecto.UUID.generate(), user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns nil when layout does not belong to user's organisation" do
      user = insert(:user_with_organisation)
      layout = insert(:layout)
      s_layout = Layouts.show_layout(layout.id, user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns nil when wrong datas are given" do
      s_layout = Layouts.show_layout(1, nil)
      assert s_layout == {:error, :fake}
    end
  end

  describe "layout_files_upload/2" do
    # TO_DO update tests
    test "slug file upload for a layout" do
      user = insert(:user)
      layout = insert(:layout, creator: user)

      params = %{
        "slug_file" => %Plug.Upload{
          path: "test/fixtures/example.png",
          filename: "example.png"
        }
      }

      u_layout = Layouts.layout_files_upload(layout, params)
      #      dir = "uploads/slug/#{layout.id}"
      assert params["slug_file"].filename == "example.png"
    end

    test "screenshot file upload for a layout" do
      user = insert(:user)
      layout = insert(:layout, creator: user)

      params = %{
        "screenshot" => %Plug.Upload{
          path: "test/fixtures/example.png",
          filename: "example.png"
        }
      }

      u_layout = Layouts.layout_files_upload(layout, params)

      assert u_layout.screenshot.file_name == "example.png"
    end
  end

  describe "get_layout/2" do
    test "get layout returns the layout data by uuid" do
      user = insert(:user_with_organisation)
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))
      s_layout = Layouts.get_layout(layout.id, user)
      assert s_layout.name == layout.name
      assert s_layout.description == layout.description
      assert s_layout.width == layout.width
      assert s_layout.height == layout.height
      assert s_layout.unit == layout.unit
      assert s_layout.slug == layout.slug
    end

    test "returns error invalid id with non-existent UUIDs" do
      user = insert(:user_with_organisation)
      s_layout = Layouts.get_layout(Ecto.UUID.generate(), user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns error  when layout does not belong to user's organisation" do
      user = insert(:user_with_organisation)
      layout = insert(:layout)
      s_layout = Layouts.get_layout(layout.id, user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns error when wrong datas are given" do
      s_layout = Layouts.get_layout(1, nil)
      assert s_layout == {:error, :fake}
    end
  end

  describe "get_layout_asset/2" do
    @tag :skip
    test "get layout asset from its layout and assets uuids" do
      user = insert(:user)
      engine = insert(:engine)
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))
      layout = insert(:layout, creator: user, engine: engine)
      layout_asset = insert(:layout_asset, layout: layout, asset: asset, creator: user)
      g_layout_asset = Layouts.get_layout_asset(layout.id, asset.id)
      assert layout_asset.id == g_layout_asset.id
    end
  end

  describe "update_layout/3" do
    test "update layout on valid attrs" do
      user = insert(:user)
      engine = insert(:engine)
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))

      count_before =
        Layout
        |> Repo.all()
        |> length()

      params = Map.put(@valid_layout_attrs, "engine_uuid", engine.id)

      layout = Layouts.update_layout(user, layout, params)

      count_after =
        Layout
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert layout.name == @valid_layout_attrs["name"]
      assert layout.description == @valid_layout_attrs["description"]
      assert layout.width == @valid_layout_attrs["width"]
      assert layout.height == @valid_layout_attrs["height"]
      assert layout.unit == @valid_layout_attrs["unit"]
      assert layout.slug == @valid_layout_attrs["slug"]
    end

    @tag :skip
    test "update layout on invalid attrs" do
      user = insert(:user)
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))

      count_before =
        Layout
        |> Repo.all()
        |> length()

      {:error, changeset} = Layouts.update_layout(user, layout, @invalid_attrs)

      count_after =
        Layout
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               slug: ["can't be blank"]
             } == errors_on(changeset)
    end

    test "return error if layout with same name exists" do
      user = insert(:user_with_organisation)

      layout =
        insert(:layout,
          name: "Layout",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      insert(:layout,
        name: "Layout Name",
        creator: user,
        organisation: List.first(user.owned_organisations)
      )

      {:error, changeset} =
        Layouts.update_layout(user, layout, %{"name" => "Layout Name", "slug" => "pletter"})

      assert %{
               name: ["Layout with the same name exists. Use another name.!"]
             } == errors_on(changeset)
    end
  end

  describe "layout_index/2" do
    test "layout index returns the list of layouts" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{page_number: 1})

      assert layout_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ l1.name

      assert layout_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ l2.name
    end

    test "filter by name" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          name: "First Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          name: "Second Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{"name" => "First", page_number: 1})

      assert layout_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ l1.name

      refute layout_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ l2.name
    end

    test "returns an empty list when there are no matches for name keyword" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          name: "First Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          name: "Second Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{"name" => "does not exist", page_number: 1})

      refute layout_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ l1.name

      refute layout_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ l2.name
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          name: "First Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          name: "Second Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{"sort" => "name", page_number: 1})

      assert List.first(layout_index.entries).name == l1.name
      assert List.last(layout_index.entries).name == l2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          name: "First Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          name: "Second Layout",
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{"sort" => "name_desc", page_number: 1})

      assert List.first(layout_index.entries).name == l2.name
      assert List.last(layout_index.entries).name == l1.name
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(layout_index.entries).name == l1.name
      assert List.last(layout_index.entries).name == l2.name
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      engine = insert(:engine)

      l1 =
        insert(
          :layout,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      l2 =
        insert(
          :layout,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations),
          engine: engine
        )

      layout_index = Layouts.layout_index(user, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(layout_index.entries).name == l2.name
      assert List.last(layout_index.entries).name == l1.name
    end
  end

  describe "delete_layout/1" do
    test "delete layout deletes the layout and returns its data" do
      layout = insert(:layout)
      {:ok, _layout} = Layouts.delete_layout(layout)

      refute Repo.get(Layout, layout.id)
    end
  end

  describe "delete_layout_asset/1" do
    @tag :skip
    test "delete layout asset deletes a layouts asset and returns the data" do
      layout_asset = insert(:layout_asset)
      {:ok, _l_asset} = Layouts.delete_layout_asset(layout_asset)

      refute Repo.get(LayoutAsset, layout_asset.id)
    end
  end
end
