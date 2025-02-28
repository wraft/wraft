defmodule WraftDoc.DocumentTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.Account.Role
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.BlockTemplates
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.Comments
  alias WraftDoc.Comments.Comment
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Document
  alias WraftDoc.Document.Block
  alias WraftDoc.Document.CollectionForm
  alias WraftDoc.Document.CollectionFormField
  alias WraftDoc.Document.Counter
  alias WraftDoc.Document.Field
  alias WraftDoc.Document.FieldType
  alias WraftDoc.Document.Instance
  alias WraftDoc.Document.Instance.History
  alias WraftDoc.Document.Instance.Version
  alias WraftDoc.Document.InstanceApprovalSystem
  alias WraftDoc.Document.Pipeline
  alias WraftDoc.Document.Pipeline.Stage
  alias WraftDoc.Document.Pipeline.TriggerHistory
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset
  alias WraftDoc.Validations.Validation
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
  @valid_instance_attrs %{
    "instance_id" => "OFFR0001",
    "raw" => "instance raw",
    "serialized" => %{
      "body" => "body of the content",
      "title" => "title of the content"
    },
    "type" => 1,
    "state_id" => "a041a482-202c-4c53-99f3-79a8dab252d5"
  }
  @valid_content_type_attrs %{
    "name" => "content_type name",
    "description" => "content_type description",
    "color" => "#fff",
    "prefix" => "OFFRE"
  }

  @valid_theme_attrs %{
    "name" => "theme name",
    "font" => "theme font",
    "typescale" => %{
      "heading1" => 22,
      "heading2" => 16,
      "paragraph" => 12
    },
    "preview_file" => %Plug.Upload{
      filename: "invoice.pdf",
      path: "test/helper/invoice.pdf",
      content_type: "application/pdf"
    }
  }

  @valid_data_template_attrs %{
    "title" => "data_template title",
    "title_template" => "data_template title_template",
    "data" => "data_template data",
    "serialized" => %{
      "company" => "Apple"
    }
  }
  @invalid_data_template_attrs %{title: nil, title_template: nil, data: nil}
  @valid_asset_attrs %{
    "name" => "asset name",
    "type" => "layout",
    "file" => %Plug.Upload{
      content_type: "application/pdf",
      filename: "invoice.pdf",
      path: "test/helper/invoice.pdf"
    }
  }

  @valid_comment_attrs %{
    "comment" => "comment comment",
    "is_parent" => true,
    "master" => "instance",
    "master_id" => "0s3df0sd03f3s03d0f3",
    "organisation_id" => 12
  }
  @invalid_comment_attrs %{
    "comment" => nil,
    "is_parent" => nil,
    "master" => nil,
    "master_id" => nil,
    "organisation_id" => nil
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

      layout = Document.create_layout(user, engine, params)

      assert count_before + 1 ==
               Layout
               |> Repo.all()
               |> length()

      assert layout.name == @valid_layout_attrs["name"]
      assert layout.description == @valid_layout_attrs["description"]
      assert layout.width == @valid_layout_attrs["width"]
      assert layout.height == @valid_layout_attrs["height"]
      assert layout.unit == @valid_layout_attrs["unit"]
      assert layout.slug == @valid_layout_attrs["slug"]
    end

    test "create layout on invalid attrs" do
      user = insert(:user_with_organisation)

      count_before =
        Layout
        |> Repo.all()
        |> length()

      engine = insert(:engine)
      {:error, changeset} = Document.create_layout(user, engine, @invalid_attrs)

      count_after =
        Layout
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               name: ["can't be blank"],
               description: ["can't be blank"],
               slug: ["can't be blank"],
               engine_id: ["can't be blank"]
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

      {:error, changeset} = Document.create_layout(user, engine, params)

      assert %{
               name: ["Layout with the same name exists. Use another name.!"]
             } == errors_on(changeset)
    end
  end

  describe "engine_list/1" do
    test "list all engines" do
      engin_params = %{name: "engin", api_route: "api_route"}
      engine = Document.engines_list(engin_params)
      assert true == is_list(engine.entries)

      assert true ==
               engine.entries
               |> length()
               |> is_number()
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

      s_layout = Document.show_layout(layout.id, user)

      assert s_layout.name == layout.name
      assert s_layout.description == layout.description
      assert s_layout.creator.name == user.name
      assert s_layout.engine.name == engine.name
    end

    test "returns nil with non-existent UUIDs" do
      user = insert(:user_with_organisation)
      s_layout = Document.show_layout(Ecto.UUID.generate(), user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns nil when layout does not belong to user's organisation" do
      user = insert(:user_with_organisation)
      layout = insert(:layout)
      s_layout = Document.show_layout(layout.id, user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns nil when wrong datas are given" do
      s_layout = Document.show_layout(1, nil)
      assert s_layout == {:error, :fake}
    end
  end

  describe "layout_files_upload/2" do
    test "slug file upload for a layout" do
      user = insert(:user)
      layout = insert(:layout, creator: user)

      params = %{
        "slug_file" => %Plug.Upload{
          path: "test/fixtures/example.png",
          filename: "example.png"
        }
      }

      u_layout = Document.layout_files_upload(layout, params)
      #      dir = "uploads/slug/#{layout.id}"
      assert u_layout.slug_file.file_name == "example.png"
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

      u_layout = Document.layout_files_upload(layout, params)

      assert u_layout.screenshot.file_name == "example.png"
    end
  end

  describe "get_layout/2" do
    test "get layout returns the layout data by uuid" do
      user = insert(:user_with_organisation)
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))
      s_layout = Document.get_layout(layout.id, user)
      assert s_layout.name == layout.name
      assert s_layout.description == layout.description
      assert s_layout.width == layout.width
      assert s_layout.height == layout.height
      assert s_layout.unit == layout.unit
      assert s_layout.slug == layout.slug
    end

    test "returns error invalid id with non-existent UUIDs" do
      user = insert(:user_with_organisation)
      s_layout = Document.get_layout(Ecto.UUID.generate(), user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns error  when layout does not belong to user's organisation" do
      user = insert(:user_with_organisation)
      layout = insert(:layout)
      s_layout = Document.get_layout(layout.id, user)
      assert s_layout == {:error, :invalid_id, "Layout"}
    end

    test "returns error when wrong datas are given" do
      s_layout = Document.get_layout(1, nil)
      assert s_layout == {:error, :fake}
    end
  end

  describe "get_layout_asset/2" do
    test "get layout asset from its layout and assets uuids" do
      user = insert(:user)
      engine = insert(:engine)
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))
      layout = insert(:layout, creator: user, engine: engine)
      layout_asset = insert(:layout_asset, layout: layout, asset: asset, creator: user)
      g_layout_asset = Document.get_layout_asset(layout.id, asset.id)
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

      layout = Document.update_layout(layout, user, params)

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

    test "update layout on invalid attrs" do
      user = insert(:user)
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))

      count_before =
        Layout
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.update_layout(layout, user, @invalid_attrs)

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
        Document.update_layout(layout, user, %{"name" => "Layout Name", "slug" => "pletter"})

      assert %{
               name: ["Layout with the same name exists. Use another name.!"]
             } == errors_on(changeset)
    end
  end

  describe "delete_layout/1" do
    test "delete layout deletes the layout and returns its data" do
      layout = insert(:layout)
      {:ok, _layout} = Document.delete_layout(layout)

      refute Repo.get(Layout, layout.id)
    end
  end

  describe "delete_layout_asset/1" do
    test "delete layout asset deletes a layouts asset and returns the data" do
      layout_asset = insert(:layout_asset)
      {:ok, _l_asset} = Document.delete_layout_asset(layout_asset)

      refute Repo.get(LayoutAsset, layout_asset.id)
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

      layout_index = Document.layout_index(user, %{page_number: 1})

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

      layout_index = Document.layout_index(user, %{"name" => "First", page_number: 1})

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

      layout_index = Document.layout_index(user, %{"name" => "does not exist", page_number: 1})

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

      layout_index = Document.layout_index(user, %{"sort" => "name", page_number: 1})

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

      layout_index = Document.layout_index(user, %{"sort" => "name_desc", page_number: 1})

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

      layout_index = Document.layout_index(user, %{"sort" => "inserted_at", page_number: 1})

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

      layout_index = Document.layout_index(user, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(layout_index.entries).name == l2.name
      assert List.last(layout_index.entries).name == l1.name
    end
  end

  describe "create_content_type/2" do
    test "create content_type on valid attributes" do
      user = insert(:user_with_organisation)
      file_field_type = Repo.get_by(FieldType, name: "File Input")
      string_field_type = Repo.get_by(FieldType, name: "String")

      [organisation] = user.owned_organisations
      %{id: layout_id} = insert(:layout, organisation: organisation)
      %{id: flow_id} = insert(:flow, organisation: organisation)
      %{id: theme_id} = theme = insert(:theme, organisation: organisation)

      asset = insert(:asset, type: "theme", organisation: organisation)
      insert(:theme_asset, theme: theme, asset: asset)

      fields = [
        %{
          "name" => "Photo",
          "field_type_id" => file_field_type.id,
          "meta" => %{"src" => "/img/img.png", "alt" => "Image"},
          "description" => "Upload your photo"
        },
        %{
          "name" => "Name",
          "field_type_id" => string_field_type.id,
          "meta" => %{},
          "description" => "Enter your name"
        }
      ]

      param =
        Map.merge(@valid_content_type_attrs, %{
          "fields" => fields,
          "theme_id" => theme_id,
          "flow_id" => flow_id,
          "layout_id" => layout_id
        })

      %{theme: %{assets: [theme_asset]}} =
        content_type = Document.create_content_type(user, param)

      assert content_type.name == @valid_content_type_attrs["name"]
      assert content_type.description == @valid_content_type_attrs["description"]
      assert content_type.color == @valid_content_type_attrs["color"]
      assert content_type.prefix == @valid_content_type_attrs["prefix"]
      assert content_type.id

      assert content_type.theme.id == theme_id
      assert theme_asset.id == asset.id

      assert Enum.map(
               content_type.fields,
               &%{
                 "name" => &1.name,
                 "field_type_id" => &1.field_type_id,
                 "meta" => &1.meta,
                 "description" => &1.description
               }
             ) == fields
    end

    test "returns error on invalid attrs" do
      user = insert(:user_with_organisation)

      {:error, changeset} = Document.create_content_type(user, @invalid_attrs)

      assert %{
               name: ["can't be blank"],
               prefix: ["can't be blank"],
               flow_id: ["can't be blank"],
               layout_id: ["can't be blank"],
               theme_id: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "content_type_index/2" do
    test "content_type index lists the content_type data" do
      user = insert(:user_with_organisation)

      c1 =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      c2 =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      content_type_index = ContentTypes.content_type_index(user, %{page_number: 1})

      assert content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c1.name

      assert content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c2.name
    end

    test "filters by name" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          name: "content type A",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          name: "content type B",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index = ContentTypes.content_type_index(user, %{"name" => "A", page_number: 1})

      assert content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c1.name

      refute content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c2.name
    end

    test "returns an empty list when there are no matches for the name keyword" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          name: "content type A",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          name: "content type B",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"name" => "does not exist", page_number: 1})

      refute content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c1.name

      refute content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c2.name
    end

    test "filters by prefix" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          prefix: "prefix A",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          prefix: "prefix B",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"prefix" => "A", page_number: 1})

      assert content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c1.name

      refute content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c2.name
    end

    test "returns an empty list when there are no matches for prefix keyword" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          prefix: "prefix A",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          prefix: "prefix B",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"prefix" => "does not exist", page_number: 1})

      refute content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c1.name

      refute content_type_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~
               c2.name
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          name: "content type A",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          name: "content type B",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"sort" => "name", page_number: 1})

      assert List.first(content_type_index.entries).name == c1.name
      assert List.last(content_type_index.entries).name == c2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          name: "content type A",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          name: "content type B",
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"sort" => "name_desc", page_number: 1})

      assert List.first(content_type_index.entries).name == c2.name
      assert List.last(content_type_index.entries).name == c1.name
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(content_type_index.entries).name == c1.name
      assert List.last(content_type_index.entries).name == c2.name
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)

      c1 =
        insert(
          :content_type,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      c2 =
        insert(
          :content_type,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: List.first(user.owned_organisations)
        )

      content_type_index =
        ContentTypes.content_type_index(user, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(content_type_index.entries).name == c2.name
      assert List.last(content_type_index.entries).name == c1.name
    end
  end

  describe "show_content_type/2" do
    test "show content_type shows the content_type data" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      layout = insert(:layout, creator: user, organisation: organisation)
      flow = insert(:flow, creator: user, organisation: organisation)

      theme = insert(:theme, organisation: organisation)
      asset = insert(:asset, type: "theme", organisation: organisation)
      insert(:theme_asset, theme: theme, asset: asset)

      content_type =
        insert(
          :content_type,
          creator: user,
          layout: layout,
          flow: flow,
          theme: theme,
          organisation: organisation
        )

      s_content_type = Document.show_content_type(user, content_type.id)
      assert s_content_type.name == content_type.name
      assert s_content_type.description == content_type.description
      assert s_content_type.color == content_type.color
      assert s_content_type.prefix == content_type.prefix
      assert s_content_type.layout.name == layout.name
      assert s_content_type.theme.name == theme.name
    end
  end

  describe "get_content_type/2" do
    test "get content_type shows the content_type data" do
      user = insert(:user_with_organisation)

      content_type = insert(:content_type, organisation: List.first(user.owned_organisations))
      s_content_type = Document.get_content_type(user, content_type.id)

      assert s_content_type.name == content_type.name
      assert s_content_type.description == content_type.description
      assert s_content_type.color == content_type.color
      assert s_content_type.prefix == content_type.prefix
    end

    test "returns an error if the content_type does not exist" do
      user = insert(:user_with_organisation)

      assert {:error, :invalid_id, "ContentType"} =
               Document.get_content_type(user, Ecto.UUID.generate())
    end

    test "return an error for non-existent organisation and content type" do
      user = insert(:user)
      assert {:error, :invalid_id, "ContentType"} == Document.get_content_type(user, nil)
    end

    test "return an error for invalid input" do
      assert {:error, :fake} == Document.get_content_type(nil, nil)
    end
  end

  describe "get_content_type_from_id/1" do
    test "gets a content type from its ID and fetches all its related data" do
      user = insert(:user)
      layout = insert(:layout)

      content =
        insert(
          :content_type,
          creator: user,
          layout: layout,
          organisation: List.first(user.owned_organisations)
        )

      content_type = Document.get_content_type_from_id(content.id)
      assert content_type.name == content.name
    end
  end

  describe "update_content_type/3" do
    test "update content_type on valid attrs" do
      file_field_type = Repo.get_by(FieldType, name: "File Input")
      string_field_type = Repo.get_by(FieldType, name: "String")

      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      layout = insert(:layout, creator: user, organisation: organisation)
      flow = insert(:flow, creator: user, organisation: organisation)
      theme = insert(:theme, creator: user, organisation: organisation)

      content_type =
        insert(
          :content_type,
          creator: user,
          layout: layout,
          flow: flow,
          organisation: organisation,
          theme: theme
        )

      fields = [
        %{
          "name" => "Photo",
          "field_type_id" => file_field_type.id,
          "meta" => %{"src" => "/img/img.png", "alt" => "Image"},
          "description" => "Upload your photo"
        },
        %{
          "name" => "Name",
          "field_type_id" => string_field_type.id,
          "meta" => %{},
          "description" => "Enter your name"
        }
      ]

      params =
        Map.merge(
          @valid_content_type_attrs,
          %{
            "flow_uuid" => flow.id,
            "layout_uuid" => layout.id,
            "fields" => fields
          }
        )

      content_type = Document.update_content_type(content_type, user, params)

      assert content_type.name == @valid_content_type_attrs["name"]
      assert content_type.description == @valid_content_type_attrs["description"]
      assert content_type.color == @valid_content_type_attrs["color"]
      assert content_type.prefix == @valid_content_type_attrs["prefix"]

      assert Enum.sort(
               Enum.map(
                 content_type.fields,
                 &%{
                   "name" => &1.name,
                   "field_type_id" => &1.field_type_id,
                   "meta" => &1.meta,
                   "description" => &1.description
                 }
               )
             ) == Enum.sort(fields)
    end

    test "update content_type on invalid attrs" do
      user = insert(:user)
      content_type = insert(:content_type, creator: user)

      params = Map.merge(@invalid_attrs, %{name: "", description: "", prefix: "", theme_id: nil})
      {:error, changeset} = Document.update_content_type(content_type, user, params)

      assert %{
               name: ["can't be blank"],
               description: ["can't be blank"],
               prefix: ["can't be blank"],
               theme_id: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "delete_content_type/2" do
    test "delete content_type deletes the content_type data" do
      content_type = insert(:content_type)
      {:ok, _content_type} = Document.delete_content_type(content_type)

      refute Repo.get(ContentType, content_type.id)
    end
  end

  describe "create_instance/4" do
    test "create instance on valid attributes and updates count of instances at counter" do
      user = insert(:user)
      content_type = insert(:content_type)
      flow = content_type.flow
      state = insert(:state, flow: flow)
      state_id = state.id

      params = %{
        "instance_id" => "OFFR0001",
        "raw" => "instance raw",
        "serialized" => %{
          "body" => "body of the content",
          "title" => "title of the content"
        },
        "type" => 1,
        "state_id" => "a041a482-202c-4c53-99f3-79a8dab252d5"
      }

      params = Map.merge(params, %{"state_id" => state_id})

      counter_count =
        Counter
        |> Repo.all()
        |> length()

      count_before =
        Instance
        |> Repo.all()
        |> length()

      instance = Document.create_instance(user, content_type, state, params)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      counter_count_after =
        Counter
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert counter_count + 1 == counter_count_after
      assert instance.raw == @valid_instance_attrs["raw"]
      assert instance.serialized == @valid_instance_attrs["serialized"]
    end

    test "does not create instance, on invalid attrs" do
      user = insert(:user)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      content_type = insert(:content_type)
      state = insert(:state, flow: content_type.flow)

      {:error, changeset} = Document.create_instance(user, content_type, state, @invalid_attrs)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               raw: ["can't be blank"],
               type: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "create_instance/3" do
    test "create an instance on valid attributes and updates count of instances at counter" do
      user = insert(:user)
      content_type = insert(:content_type)
      flow = content_type.flow
      state = insert(:state, flow: flow)
      state_id = state.id

      params = %{
        "instance_id" => "OFFR0001",
        "raw" => "instance raw",
        "serialized" => %{
          "body" => "body of the content",
          "title" => "title of the content"
        },
        "type" => 1,
        "state_id" => "a041a482-202c-4c53-99f3-79a8dab252d5"
      }

      params = Map.merge(params, %{"state_id" => state_id})

      counter_count =
        Counter
        |> Repo.all()
        |> length()

      count_before =
        Instance
        |> Repo.all()
        |> length()

      instance = Document.create_instance(user, content_type, params)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      counter_count_after =
        Counter
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert counter_count + 1 == counter_count_after
      assert instance.raw == @valid_instance_attrs["raw"]
      assert instance.serialized == @valid_instance_attrs["serialized"]
    end

    test "does not create instance, on invalid attrs" do
      user = insert(:user)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      content_type = insert(:content_type)
      _state = insert(:state, flow: content_type.flow)

      {:error, changeset} = Document.create_instance(user, content_type, @invalid_attrs)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               raw: ["can't be blank"],
               type: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "delete_instance/1" do
    test "deletes an instance" do
      instance = insert(:instance)
      {:ok, _del_instance} = Document.delete_instance(instance)

      refute Repo.get(Instance, instance.id)
    end
  end

  describe "delete_uploaded_docs/1" do
    test "returns success tuple on succesfully deleting the documents from MinIO" do
      instance = insert(:instance)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      assert {:ok, _} = Document.delete_instance(instance)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert count_before == count_after + 1
    end

    test "returns error tuple when AWS request fails" do
      user = insert(:user)
      instance = insert(:instance, allowed_users: [user.id])

      ExAwsMock
      |> expect(
        :stream!,
        fn %ExAws.Operation.S3{} = operation ->
          assert operation.http_method == :get

          assert operation.params == %{
                   "prefix" =>
                     "organisations/#{user.current_org_id}/contents/#{instance.instance_id}"
                 }

          {:error, :reason}
        end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3DeleteAllObjects{} ->
          {:error, :reason}
        end
      )

      {:error, :reason} = Document.delete_uploaded_docs(user, instance)
      assert :ok == Mox.verify!()
    end
  end

  describe "instance_index/2" do
    test "instance index lists the instance data" do
      user = insert(:user)
      content_type = insert(:content_type)
      i1 = insert(:instance, creator: user, content_type: content_type)
      i2 = insert(:instance, creator: user, content_type: content_type)
      instance_index = Document.instance_index(content_type.id, %{page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.raw end)
             |> List.to_string() =~
               i1.raw

      assert instance_index.entries
             |> Enum.map(fn x -> x.raw end)
             |> List.to_string() =~ i2.raw
    end

    test "return error for invalid input" do
      instance_index = Document.instance_index("invalid", "invalid")
      assert instance_index == {:error, :invalid_id}
    end

    test "filter by instance_id" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"instance_id" => "RO64NNYM", page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "filter by creator_id" do
      creator_1 = insert(:user, name: "User 1")
      creator_2 = insert(:user, name: "User 2")
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: creator_1,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: creator_2,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"creator_id" => creator_1.id, page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return the default index if the creator id is invalid" do
      creator_1 = insert(:user, name: "User 1")
      creator_2 = insert(:user, name: "User 2")
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: creator_1,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: creator_2,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"creator_id" => "invalid", page_number: 1})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list if there are no matches for creator_id" do
      creator_1 = insert(:user, name: "User 1")
      creator_2 = insert(:user, name: "User 2")
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: creator_1,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: creator_2,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{
          "creator_id" => Ecto.UUID.generate(),
          page_number: 1
        })

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "returns an empty list when there are no matches for instance_id keyword" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(
          content_type.id,
          %{
            "instance_id" => "does not exist",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "sorts by instance_id in ascending order when sort key is instance_id" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"sort" => "instance_id", page_number: 1})

      assert List.first(instance_index.entries).instance_id == i1.instance_id
      assert List.last(instance_index.entries).instance_id == i2.instance_id
    end

    test "sorts by instance_id in descending order when sort key is instance_id_desc" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          instance_id: "DO745U6M67191879878164811475",
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          creator: user,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"sort" => "instance_id_desc", page_number: 1})

      assert List.first(instance_index.entries).instance_id == i2.instance_id
      assert List.last(instance_index.entries).instance_id == i1.instance_id
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(instance_index.entries).raw == i1.raw
      assert List.last(instance_index.entries).raw == i2.raw
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user)
      content_type = insert(:content_type)

      i1 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          content_type: content_type
        )

      i2 =
        insert(
          :instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          content_type: content_type
        )

      instance_index =
        Document.instance_index(content_type.id, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(instance_index.entries).raw == i2.raw
      assert List.last(instance_index.entries).raw == i1.raw
    end
  end

  # TODO update the tests as per the new implementation
  describe "instance_index_of_an_organisation/2" do
    test "instance index of an organisation lists instances under an organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)

      i1 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      instance_index_under_organisation =
        Document.instance_index_of_an_organisation(user, %{page_number: 1})

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    test "instance index returns nil if user is not part of the organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      external_user =
        insert(:user_with_organisation, owned_organisations: [insert(:organisation)])

      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)
      i1 = insert(:instance, content_type: content_type, creator: user, state: state)
      i2 = insert(:instance, content_type: content_type, creator: user, state: state)

      instance_index_under_organisation =
        Document.instance_index_of_an_organisation(external_user, %{page_number: 1})

      refute instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    test "instance index returns if the user is a collaborator" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      flow = insert(:flow, organisation: organisation)
      state = insert(:state, organisation: organisation, flow: flow)

      user_collab =
        insert(:user_with_organisation,
          current_org_id: organisation.id,
          owned_organisations: [organisation]
        )

      i1 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id, user_collab.id]
        )

      i2 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      insert(:content_collab, user: user_collab, content: i1, state: state)

      instance_index_under_organisation =
        Document.instance_index_of_an_organisation(user_collab, %{page_number: 1})

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    test "instance index returns nil if the user is collaborator but not part of the organisation" do
      # TODO
    end

    test "instance index returns if the user is an approver" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      flow = insert(:flow, organisation: organisation)
      state = insert(:state, organisation: organisation, flow: flow)

      approver =
        insert(:user_with_organisation,
          current_org_id: organisation.id,
          owned_organisations: [organisation]
        )

      i1 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [approver.id]
        )

      i2 =
        insert(:instance,
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [approver.id]
        )

      insert(:state_users, user: approver, state: state)

      instance_index_under_organisation =
        Document.instance_index_of_an_organisation(approver, %{page_number: 1})

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index_under_organisation.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~ i2.instance_id
    end

    test "instance index returns nil if the user is an approver but not part of the organisation" do
      # TODO
    end

    test "return error for invalid input" do
      instance_index = Document.instance_index_of_an_organisation("invalid", "invalid")
      assert instance_index == {:error, :invalid_id}
    end

    test "filter by instance_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state = insert(:state, organisation: organisation)

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "instance_id" => "RO64NNYM",
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "returns an empty list when there are no matches for instance_id keyword" do
      user = insert(:user_with_organisation)
      content_type = insert(:content_type, organisation: List.first(user.owned_organisations))

      i1 = insert(:instance, instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5", content_type: content_type)

      i2 =
        insert(:instance, instance_id: "DO745U6M67191879878164811475", content_type: content_type)

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "instance_id" => "does not exist",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "filter by content_type_name" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)

      content_type1 = insert(:content_type, name: "Letter", organisation: organisation)

      content_type2 = insert(:content_type, name: "Contract", organisation: organisation)

      instance1 =
        insert(:instance, content_type: content_type1, state: state, allowed_users: [user.id])

      instance2 =
        insert(:instance, content_type: content_type2, state: state, allowed_users: [user.id])

      instance_index =
        Document.instance_index_of_an_organisation(user, %{"content_type_name" => "Letter"})

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance2.instance_id
    end

    test "returns an empty list when there are no EXACT matches for content_type_name keyword" do
      user = insert(:user_with_organisation)

      content_type1 =
        insert(:content_type, name: "Letter", organisation: List.first(user.owned_organisations))

      content_type2 =
        insert(:content_type,
          name: "Contract",
          organisation: List.first(user.owned_organisations)
        )

      instance1 = insert(:instance, content_type: content_type1)

      instance2 = insert(:instance, content_type: content_type2)

      instance_index =
        Document.instance_index_of_an_organisation(user, %{"content_type_name" => "letter"})

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               instance2.instance_id
    end

    test "filter by creator_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "creator_id" => creator.id,
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list if there are no matches for creator_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "creator_id" => Ecto.UUID.generate(),
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return the default index if the creator id is invalid" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      creator =
        insert(:user,
          name: "creator",
          current_org_id: organisation.id,
          owned_organisations: [organisation]
        )

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state,
          allowed_users: [creator.id, user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state,
          allowed_users: [creator.id, user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "creator_id" => "invalid",
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "filter by state" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft", organisation: organisation)
      state_2 = insert(:state, state: "published", organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1,
          allowed_users: [creator.id, user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2,
          allowed_users: [creator.id, user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "state" => state_1.state,
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "returns an empty list when the state does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft")
      state_2 = insert(:state, state: "published")

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "state" => state_1.state,
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list for invalid state" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft")
      state_2 = insert(:state, state: "published")

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "state" => "invalid",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "filter by document instance title name" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft", organisation: organisation)
      state_2 = insert(:state, state: "published", organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1,
          serialized: %{title: "Title A", body: "Body of the content"},
          allowed_users: [creator.id, user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2,
          serialized: %{title: "Title B", body: "Body of the content"},
          allowed_users: [creator.id, user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "document_instance_title" => "Title A",
            page_number: 1
          }
        )

      assert instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "return an empty list for invalid document instance title name" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, organisation: organisation)
      state_1 = insert(:state, state: "draft", organisation: organisation)
      state_2 = insert(:state, state: "published", organisation: organisation)

      creator = insert(:user, name: "creator", owned_organisations: [organisation])

      i1 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          creator: creator,
          state: state_1,
          serialized: %{title: "Title A", body: "Body of the content"}
        )

      i2 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          creator: user,
          state: state_2,
          serialized: %{title: "Title B", body: "Body of the content"}
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "document_instance_title" => "Invalid Title",
            page_number: 1
          }
        )

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i1.instance_id

      refute instance_index.entries
             |> Enum.map(fn x -> x.instance_id end)
             |> List.to_string() =~
               i2.instance_id
    end

    test "sorts by instance_id in ascending order when sort key is instance_id" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "instance_id",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).instance_id == i1.instance_id
      assert List.last(instance_index.entries).instance_id == i2.instance_id
    end

    test "sorts by instance_id in descending order when sort key is instance_id_desc" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          instance_id: "DO745U6M67191879878164811475",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          instance_id: "RO64NNYMH9DSIDMLZ8JQWQQ5",
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "instance_id_desc",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).instance_id == i2.instance_id
      assert List.last(instance_index.entries).instance_id == i1.instance_id
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "inserted_at",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).raw == i1.raw
      assert List.last(instance_index.entries).raw == i2.raw
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation)

      i1 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:56:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      i2 =
        insert(:instance,
          inserted_at: ~N[2023-04-18 11:57:34],
          content_type: content_type,
          state: state,
          allowed_users: [user.id]
        )

      instance_index =
        Document.instance_index_of_an_organisation(
          user,
          %{
            "sort" => "inserted_at_desc",
            page_number: 1
          }
        )

      assert List.first(instance_index.entries).raw == i2.raw
      assert List.last(instance_index.entries).raw == i1.raw
    end
  end

  describe "get_instance/2" do
    test "get instance shows the instance data" do
      user = insert(:user_with_organisation)

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      instance = insert(:instance, creator: user, content_type: content_type)
      i_instance = Document.get_instance(instance.id, user)
      assert i_instance.instance_id == instance.instance_id
      assert i_instance.raw == instance.raw
    end
  end

  describe "show_instance/2" do
    test "show instance shows and preloads creator content type layout and state instance data" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, creator: user, organisation: organisation)
      flow = content_type.flow
      state = insert(:state, flow: flow, organisation: organisation)
      instance = insert(:instance, creator: user, content_type: content_type, state: state)

      i_instance = Document.show_instance(instance.id, user)
      assert i_instance.instance_id == instance.instance_id
      assert i_instance.raw == instance.raw

      assert i_instance.creator.name == user.name
      assert i_instance.content_type.name == content_type.name
      assert i_instance.state.state == state.state
    end
  end

  describe "get_built_document/1" do
    test "Get the build document of the given instance." do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      content_type = insert(:content_type, creator: user, organisation: organisation)
      flow = content_type.flow
      state = insert(:state, flow: flow, organisation: organisation)

      instance =
        insert(:instance, build: "build", creator: user, content_type: content_type, state: state)

      get_built_document = Document.get_built_document(instance)

      assert instance.build == get_built_document.build
      assert instance.id == get_built_document.id
      assert instance.instance_id == get_built_document.instance_id
    end
  end

  describe "update_instance/2" do
    test "updates instance on valid attrs" do
      instance = insert(:instance)
      instance = Document.update_instance(instance, @valid_instance_attrs)

      assert instance.instance_id == @valid_instance_attrs["instance_id"]
      assert instance.raw == @valid_instance_attrs["raw"]
      assert instance.serialized == @valid_instance_attrs["serialized"]
    end

    test "returns error changeset on invalid attrs" do
      user = insert(:user)

      instance = insert(:instance, creator: user)

      count_before =
        Instance
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.update_instance(instance, @invalid_instance_attrs)

      count_after =
        Instance
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{raw: ["can't be blank"]} ==
               errors_on(changeset)
    end
  end

  describe "update_instance_state/2" do
    test "updates state of an instance when flow ID of state and flow ID of instance's content type" do
      content_type = insert(:content_type)
      state = insert(:state, flow: content_type.flow)
      instance = insert(:instance, content_type: content_type)

      instance = Document.update_instance_state(instance, state)

      assert instance.state_id == state.id
    end

    test "retrurns :error when flow ID of new state doesnt match with flow ID of instance's content type" do
      instance = insert(:instance)
      state = insert(:state)
      assert :error = Document.update_instance_state(instance, state)
    end
  end

  @tag :individual
  describe "insert_data_template_bulk/4" do
    test "test bulk data template creation with valid data" do
      c_type = insert(:content_type)
      user = insert(:user)
      mapping = %{"Title" => "title", "TitleTemplate" => "title_template", "Data" => "data"}
      path = "test/helper/data_template_source.csv"

      count_before =
        DataTemplate
        |> Repo.all()
        |> length()

      data_templates =
        user
        |> DataTemplates.insert_data_template_bulk(c_type, mapping, path)
        |> Enum.map(fn {:ok, x} -> x.title end)
        |> List.to_string()

      assert count_before + 3 ==
               DataTemplate
               |> Repo.all()
               |> length()

      assert data_templates =~ "Title1"
      assert data_templates =~ "Title2"
      assert data_templates =~ "Title3"
    end

    test "test does not do bulk data template creation with invalid data" do
      count_before =
        DataTemplate
        |> Repo.all()
        |> length()

      response = DataTemplates.insert_data_template_bulk(nil, nil, nil, nil)

      assert count_before ==
               DataTemplate
               |> Repo.all()
               |> length()

      assert response == {:error, :not_found}
    end
  end

  describe "create_data_template/3" do
    test "test creates data template with valid attrs" do
      user = insert(:user)
      c_type = insert(:content_type)

      params = %{
        "title" => "Offer letter tempalate",
        "title_template" => "Hi [employee], we welcome you to our [company], [address]",
        "data" => "Hi [employee], we welcome you to our [company], [address]",
        "serialized" => %{
          employee: "John",
          company: "Apple",
          address: "Silicon Valley"
        }
      }

      count_before =
        DataTemplate
        |> Repo.all()
        |> length()

      {:ok, data_template} = Document.create_data_template(user, c_type, params)

      assert count_before + 1 ==
               DataTemplate
               |> Repo.all()
               |> length()

      assert data_template.title == "Offer letter tempalate"

      assert data_template.title_template ==
               "Hi [employee], we welcome you to our [company], [address]"

      assert data_template.data == "Hi [employee], we welcome you to our [company], [address]"

      assert data_template.serialized == %{
               employee: "John",
               company: "Apple",
               address: "Silicon Valley"
             }
    end

    test "test does not create data template with invalid attrs" do
      user = insert(:user)
      c_type = insert(:content_type)
      {:error, changeset} = Document.create_data_template(user, c_type, %{})

      assert %{
               title: ["can't be blank"],
               title_template: ["can't be blank"],
               data: ["can't be blank"]
             } ==
               errors_on(changeset)
    end
  end

  describe "block_template_bulk_insert/3" do
    test "test bulk block template creation with valid data" do
      user = insert(:user_with_organisation)
      mapping = %{"Body" => "body", "Serialized" => "serialized", "Title" => "title"}
      path = "test/helper/block_template_source.csv"

      count_before =
        BlockTemplate
        |> Repo.all()
        |> length()

      block_templates =
        user
        |> BlockTemplates.block_template_bulk_insert(mapping, path)
        |> Enum.map(fn x -> x.title end)
        |> List.to_string()

      assert count_before + 3 ==
               BlockTemplate
               |> Repo.all()
               |> length()

      assert block_templates =~ "B Temp1"
      assert block_templates =~ "B Temp2"
      assert block_templates =~ "B Temp3"
    end

    test "test doesn not do bulk block template creation with invalid data" do
      count_before =
        BlockTemplate
        |> Repo.all()
        |> length()

      response = BlockTemplates.block_template_bulk_insert(nil, nil, nil)

      assert count_before ==
               BlockTemplate
               |> Repo.all()
               |> length()

      assert response == {:error, :not_found}
    end
  end

  describe "create block_template" do
    test "create_block_template/2, test creates block template with valid attrs" do
      user = insert(:user_with_organisation)

      params = %{
        title: "Introduction",
        body: "Hi [employee], we welcome you to our [company], [address]",
        serialized: "Hi [employee], we welcome you to our family"
      }

      count_before =
        BlockTemplate
        |> Repo.all()
        |> length()

      block_template = BlockTemplates.create_block_template(user, params)

      assert count_before + 1 ==
               BlockTemplate
               |> Repo.all()
               |> length()

      assert block_template.title == "Introduction"
      assert block_template.body == "Hi [employee], we welcome you to our [company], [address]"
      assert block_template.serialized == "Hi [employee], we welcome you to our family"
    end

    test "create_block_template/2, test does not create block template with invalid attrs" do
      user = insert(:user_with_organisation)
      {:error, changeset} = BlockTemplates.create_block_template(user, %{})

      assert %{
               title: ["can't be blank"],
               serialized: ["can't be blank"],
               body: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "get block_template" do
    test "get_block_template/2, Create a block template" do
      user = insert(:user_with_organisation)
      block_template = insert(:block_template, organisation: List.first(user.owned_organisations))
      get_block_template = BlockTemplates.get_block_template(block_template.id, user)

      assert block_template.id == get_block_template.id
      assert block_template.organisation_id == get_block_template.organisation_id
    end
  end

  describe "update_block_template/2" do
    test "updates block template with valid attrs" do
      block_template = insert(:block_template)
      params = %{"title" => "new title", "body" => "new body"}
      update_btemplate = BlockTemplates.update_block_template(block_template, params)

      assert update_btemplate.title =~ "new title"
      assert update_btemplate.body =~ "new body"
    end

    test "returns error with invalid attrs" do
      block_template = insert(:block_template)
      params = %{"title" => nil, "body" => "new body"}
      {:error, changeset} = BlockTemplates.update_block_template(block_template, params)

      assert %{title: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "delete_block_template" do
    test "deletes block_template with valid attrs" do
      block_template = insert(:block_template)
      {:ok, _delete_btemp} = BlockTemplates.delete_block_template(block_template)
      refute Repo.get(BlockTemplate, block_template.id)
    end

    test "returns error with invalid attrs" do
      assert {:error, :fake} = BlockTemplates.delete_block_template(nil)
    end
  end

  describe "get index of block_template" do
    test "index_block_template/2, Index of a block template by organisation" do
      user = insert(:user_with_organisation)

      b_temp =
        :block_template
        |> insert()
        |> Map.from_struct()

      bt_index = BlockTemplates.index_block_template(user, b_temp)

      assert Map.has_key?(bt_index, :entries)
      assert Map.has_key?(bt_index, :total_entries)
      assert is_number(bt_index.total_pages)
    end
  end

  describe "insert_bulk_build_work/6" do
    test "test creates bulk build backgroung job with valid attrs" do
      user = insert(:user)
      %{id: c_type_id} = insert(:content_type)
      %{id: state_id} = insert(:state)
      %{id: d_temp_id} = insert(:data_template)
      mapping = %{test: "map"}
      file = Plug.Upload.random_file!("test")
      tmp_file_source = "temp/bulk_build_source/" <> file

      count_before =
        Oban.Job
        |> Repo.all()
        |> length()

      {:ok, job} =
        Document.insert_bulk_build_work(
          user,
          c_type_id,
          state_id,
          d_temp_id,
          mapping,
          %Plug.Upload{filename: file, path: file}
        )

      assert count_before + 1 ==
               Oban.Job
               |> Repo.all()
               |> length()

      assert job.args == %{
               c_type_uuid: c_type_id,
               state_uuid: state_id,
               d_temp_uuid: d_temp_id,
               mapping: mapping,
               user_uuid: user.id,
               file: tmp_file_source
             }
    end

    test "does not create bulk build backgroung job with invalid attrs" do
      response = Document.insert_bulk_build_work(nil, nil, nil, nil, nil, nil)
      assert response == nil
    end
  end

  # TODO Rewrite test
  # describe "insert_data_template_bulk_import_work/4" do
  #   test "test creates bulk import data template backgroung job with valid attrs" do
  #     %{id: user_id} = insert(:user)
  #     %{id: c_type_id} = insert(:content_type)
  #     mapping = %{test: "map"}
  #     file = Plug.Upload.random_file!("test")
  #     tmp_file_source = "temp/bulk_import_source/d_template/" <> file

  #     count_before =
  #       Oban.Job
  #       |> Repo.all()
  #       |> length()

  #     {:ok, job} =
  #       DataTemplates.insert_data_template_bulk_import_work(
  #         user_id,
  #         c_type_id,
  #         mapping,
  #         %Plug.Upload{
  #           filename: file,
  #           path: file
  #         }
  #       )

  #     assert count_before + 1 ==
  #              Oban.Job
  #              |> Repo.all()
  #              |> length()

  #     assert job.args == %{
  #              user_id: user_id,
  #              c_type_uuid: c_type_id,
  #              mapping: mapping,
  #              file: tmp_file_source
  #            }
  #   end

  #   test "does not create bulk import data template backgroung job with invalid attrs" do
  #     response = DataTemplates.insert_data_template_bulk_import_work(nil, nil, nil, nil)
  #     assert response == {:error, :invalid_data}
  #   end
  # end

  # TODO Rewrite test
  # @tag :individual
  # describe "insert_block_template_bulk_import_work/3" do
  #   test "test creates bulk import block template backgroung job with valid attrs" do
  #     user = insert(:user)

  #     mapping = %{test: "map"}
  #     file = Plug.Upload.random_file!("test")
  #     tmp_file_source = "temp/bulk_import_source/b_template/" <> file

  #     count_before =
  #       Oban.Job
  #       |> Repo.all()
  #       |> length()

  #     {:ok, job} =
  #       Document.insert_block_template_bulk_import_work(
  #         user,
  #         mapping,
  #         %Plug.Upload{
  #           filename: file,
  #           path: file
  #         }
  #       )

  #     assert count_before + 1 ==
  #              Oban.Job
  #              |> Repo.all()
  #              |> length()

  #     assert job.args == %{user_id: user.id, mapping: mapping, file: tmp_file_source}
  #   end

  #   test "does not create bulk import block template backgroung job with invalid attrs" do
  #     response = Document.insert_block_template_bulk_import_work(nil, nil, nil)
  #     assert response == {:error, :invalid_data}
  #   end
  # end

  describe "get_content_type_field/2" do
    test "get content type field returns content type field data" do
      user = insert(:user_with_organisation)

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      %{id: id} = insert(:content_type_field, content_type: content_type)

      assert content_type_field = Document.get_content_type_field(id, user)
      assert content_type_field.id == id
      assert content_type_field.content_type_id == content_type.id
    end

    test "returns error for invalid content type id" do
      user = insert(:user_with_organisation)

      assert {:error, :invalid_id, "ContentTypeField"} ==
               Document.get_content_type_field(Ecto.UUID.generate(), user)
    end

    test "returns error for invalid user" do
      assert {:error, :invalid_id, "ContentTypeField"} ==
               Document.get_content_type_field(Ecto.UUID.generate(), nil)
    end

    test "returns error for non-existent content type field and non-existent organisation" do
      assert {:error, :fake} == Document.get_content_type_field(nil, %{current_org_id: nil})
    end
  end

  describe "get_content_type_field/1" do
    test "returns content type field data" do
      content_type = insert(:content_type)
      field = insert(:field)

      %{id: content_type_field_id} =
        insert(:content_type_field, content_type: content_type, field: field)

      content_type_field =
        Document.get_content_type_field(%{
          "content_type_id" => content_type.id,
          "field_id" => field.id
        })

      assert content_type_field.id == content_type_field_id
      assert content_type_field.content_type_id == content_type.id
      assert content_type_field.field_id == field.id
    end

    test "returns nil with invalid content type id and field id" do
      assert nil ==
               Document.get_content_type_field(%{
                 "content_type_id" => Ecto.UUID.generate(),
                 "field_id" => Ecto.UUID.generate()
               })
    end
  end

  describe "delete_content_type_field/1" do
    test "deletes the content_type_field and the field" do
      content_type = insert(:content_type)
      field = insert(:field)
      content_type_field = insert(:content_type_field, content_type: content_type, field: field)

      assert :ok = Document.delete_content_type_field(content_type_field)

      refute Repo.get(ContentTypeField, content_type_field.id)
      refute Repo.get(Field, field.id)
    end

    test "raises with invalid input" do
      assert_raise(FunctionClauseError, fn ->
        Document.delete_content_type_field("invalid")
      end)
    end
  end

  describe "create_or_update_counter/1" do
    test "create a row while creating an instance and write the count of instance under a content type" do
      content_type = insert(:content_type)
      {:ok, counter} = Document.create_or_update_counter(content_type)
      assert counter.count == 1
    end

    test "update counter while adding an instance on existing content type and write total count of instances under a content type" do
      content_type = insert(:content_type)

      counter = insert(:counter, subject: "ContentType:#{content_type.id}")

      {:ok, n_counter} = Document.create_or_update_counter(content_type)
      assert counter.count + 1 == n_counter.count
    end
  end

  describe "get_engine/1" do
    test "get engine returns the engine data" do
      engine = insert(:engine)
      e_engine = Document.get_engine(engine.id)
      assert engine.name == e_engine.name
      assert engine.api_route == e_engine.api_route
    end
  end

  describe "create_theme/2" do
    test "create theme on valid attributes" do
      user = insert(:user_with_organisation)
      asset1 = insert(:asset, organisation: List.first(user.owned_organisations))
      asset2 = insert(:asset, organisation: List.first(user.owned_organisations))

      count_before =
        Theme
        |> Repo.all()
        |> length()

      theme =
        Document.create_theme(
          user,
          Map.merge(@valid_theme_attrs, %{"assets" => "#{asset1.id},#{asset2.id}"})
        )

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert theme.name == @valid_theme_attrs["name"]
      assert [asset1.id, asset2.id] == Enum.map(theme.assets, & &1.id)
      assert theme.font == @valid_theme_attrs["font"]
      assert theme.typescale == @valid_theme_attrs["typescale"]
    end

    test "does not create theme on invalid attrs" do
      user = insert(:user_with_organisation)

      count_before =
        Theme
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.create_theme(user, @invalid_attrs)

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{name: ["can't be blank"], font: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "theme_preview_file_upload/2 Upload preview_file file" do
      theme = insert(:theme)

      assert {:ok, theme} =
               Document.theme_preview_file_upload(
                 theme,
                 %{
                   "preview_file" => %Plug.Upload{
                     filename: "invoice.pdf",
                     path: "test/helper/invoice.pdf"
                   }
                 }
               )

      # HACK Theme preview currently not in use, just commented for now
      # dir = "uploads/theme/theme_preview/#{theme.id}"
      # assert {:ok, ls} = File.ls(dir)
      # assert File.exists?(dir)
      # assert Enum.member?(ls, "invoice.pdf")
      assert theme.preview_file.file_name =~ "invoice.pdf"
    end
  end

  describe "theme_index/2" do
    test "theme index lists the theme data" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, creator: user, organisation: organisation)
      t2 = insert(:theme, creator: user, organisation: organisation)
      theme_index = Document.theme_index(user, %{page_number: 1})

      themes =
        theme_index.entries
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert themes =~ t1.name
      assert themes =~ t2.name
    end

    test "filter by name" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      t2 = insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Document.theme_index(user, %{"name" => "First", page_number: 1})

      themes =
        theme_index.entries
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert themes =~ t1.name
      refute themes =~ t2.name
    end

    test "returns an empty list when there are no matches for the name keyword" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Document.theme_index(user, %{"name" => "Does not exist", page_number: 1})

      assert theme_index.entries == []
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      t2 = insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Document.theme_index(user, %{"sort" => "name", page_number: 1})

      assert List.first(theme_index.entries).name == t1.name
      assert List.last(theme_index.entries).name == t2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 = insert(:theme, name: "First Theme", creator: user, organisation: organisation)
      t2 = insert(:theme, name: "Second Theme", creator: user, organisation: organisation)

      theme_index = Document.theme_index(user, %{"sort" => "name_desc", page_number: 1})

      assert List.first(theme_index.entries).name == t2.name
      assert List.last(theme_index.entries).name == t1.name
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: organisation
        )

      t2 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: organisation
        )

      theme_index = Document.theme_index(user, %{"sort" => "inserted_at", page_number: 1})

      assert List.first(theme_index.entries).name == t1.name
      assert List.last(theme_index.entries).name == t2.name
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      t1 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:56:34],
          creator: user,
          organisation: organisation
        )

      t2 =
        insert(
          :theme,
          inserted_at: ~N[2023-04-18 11:57:34],
          creator: user,
          organisation: organisation
        )

      theme_index = Document.theme_index(user, %{"sort" => "inserted_at_desc", page_number: 1})

      assert List.first(theme_index.entries).name == t2.name
      assert List.last(theme_index.entries).name == t1.name
    end
  end

  describe "get_theme/2" do
    test "get theme returns the theme data" do
      user = insert(:user_with_organisation)
      theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))
      t_theme = Document.get_theme(theme.id, user)
      assert t_theme.name == theme.name
      assert t_theme.font == theme.font
    end
  end

  describe "show_theme/2" do
    test "show theme returns the theme data and preloads the creator" do
      user = insert(:user_with_organisation)
      theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))
      t_theme = Document.show_theme(theme.id, user)
      assert t_theme.name == theme.name
      assert t_theme.font == theme.font

      assert t_theme.creator.name == user.name
    end
  end

  describe "update_theme/2" do
    test "update theme on valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      theme = insert(:theme, creator: user, organisation: organisation)
      asset1 = insert(:asset, organisation: organisation)
      asset2 = insert(:asset, organisation: organisation)

      count_before =
        Theme
        |> Repo.all()
        |> length()

      theme =
        Document.update_theme(
          theme,
          user,
          Map.merge(@valid_theme_attrs, %{"assets" => "#{asset1.id},#{asset2.id}"})
        )

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert [asset1.id, asset2.id] == Enum.map(theme.assets, & &1.id)
      assert theme.name == @valid_theme_attrs["name"]
      assert theme.font == @valid_theme_attrs["font"]
      assert theme.typescale == @valid_theme_attrs["typescale"]
    end

    test "returns error on invalid attrs" do
      user = insert(:user)
      theme = insert(:theme, creator: user)

      count_before =
        Theme
        |> Repo.all()
        |> length()

      {:error, changeset} =
        Document.update_theme(theme, user, %{name: nil, font: nil, typescale: nil, file: nil})

      count_after =
        Theme
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               name: ["can't be blank"],
               font: ["can't be blank"],
               typescale: ["can't be blank"]
             } ==
               errors_on(changeset)
    end
  end

  describe "delete_theme/1" do
    test "delete theme deletes and return the theme data" do
      user = insert(:user_with_organisation)
      theme = insert(:theme, organisation: List.first(user.owned_organisations))
      asset = insert(:asset, organisation: List.first(user.owned_organisations))
      insert(:theme_asset, theme: theme, asset: asset)

      count_before_asset = Asset |> Repo.all() |> length()
      count_before_theme_asset = ThemeAsset |> Repo.all() |> length()
      count_before_theme = Theme |> Repo.all() |> length()

      ExAwsMock
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} = operation ->
          assert operation.http_method == :get

          assert operation.params == %{
                   "prefix" =>
                     "organisations/#{user.current_org_id}/theme/theme_preview/#{theme.id}"
                 }

          {
            :ok,
            %{
              body: %{
                contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
              }
            }
          }
        end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} -> {:ok, %{body: "", status_code: 204}} end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} = operation ->
          assert operation.http_method == :get

          assert operation.params == %{
                   "prefix" => "organisations/#{user.current_org_id}/assets/#{asset.id}"
                 }

          {
            :ok,
            %{
              body: %{
                contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
              }
            }
          }
        end
      )
      |> expect(
        :request,
        fn %ExAws.Operation.S3{} -> {:ok, %{body: "", status_code: 204}} end
      )

      {:ok, t_theme} = Document.delete_theme(theme)

      count_after_asset = Asset |> Repo.all() |> length()
      count_after_theme_asset = ThemeAsset |> Repo.all() |> length()
      count_after_theme = Theme |> Repo.all() |> length()

      assert count_before_theme_asset - 1 == count_after_theme_asset
      assert count_before_asset - 1 == count_after_asset
      assert count_before_theme - 1 == count_after_theme
      assert t_theme.name == theme.name
      assert t_theme.font == theme.font
      assert t_theme.typescale == theme.typescale
    end
  end

  describe "data_template_index/2" do
    test "data_template index lists the data_template data" do
      user = insert(:user)
      content_type = insert(:content_type, creator: user)
      d1 = insert(:data_template, creator: user, content_type: content_type)
      d2 = insert(:data_template, creator: user, content_type: content_type)
      data_template_index = Document.data_template_index(content_type.id, %{page_number: 1})

      assert data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d1.title

      assert data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d2.title
    end

    test "filter by title" do
      user = insert(:user)
      content_type = insert(:content_type, creator: user)

      d1 =
        insert(:data_template, title: "First Template", creator: user, content_type: content_type)

      d2 =
        insert(:data_template,
          title: "Second Template",
          creator: user,
          content_type: content_type
        )

      data_template_index =
        Document.data_template_index(content_type.id, %{"title" => "First", page_number: 1})

      assert data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d1.title

      refute data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d2.title
    end

    test "returns an empty list when there are no matches for the title keyword" do
      user = insert(:user)
      content_type = insert(:content_type, creator: user)

      d1 =
        insert(:data_template, title: "First Template", creator: user, content_type: content_type)

      d2 =
        insert(:data_template,
          title: "Second Template",
          creator: user,
          content_type: content_type
        )

      data_template_index =
        Document.data_template_index(
          content_type.id,
          %{
            "title" => "does not exist",
            page_number: 1
          }
        )

      refute data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d1.title

      refute data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d2.title
    end
  end

  describe "data_templates_index_of_an_organisation/2" do
    test "data_template index_under_organisation lists the data_template data under an organisation" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      d1 = insert(:data_template, creator: user, content_type: content_type)
      d2 = insert(:data_template, creator: user, content_type: content_type)

      data_template_index =
        Document.data_templates_index_of_an_organisation(user, %{page_number: 1})

      assert data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d1.title

      assert data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d2.title
    end

    test "return error for invalid input pattern" do
      data_template_index =
        Document.data_templates_index_of_an_organisation("anything else", "anything else")

      assert data_template_index == {:error, :fake}
    end

    test "filter by title" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)
      content_type = insert(:content_type, organisation: organisation, creator: user)

      d1 =
        insert(:data_template, title: "First Template", creator: user, content_type: content_type)

      d2 =
        insert(:data_template,
          title: "Second Template",
          creator: user,
          content_type: content_type
        )

      data_template_index =
        Document.data_templates_index_of_an_organisation(
          user,
          %{
            "title" => "First",
            page_number: 1
          }
        )

      assert data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d1.title

      refute data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d2.title
    end

    test "returns an empty list when there are no matches for the title keyword" do
      user = insert(:user_with_organisation)
      insert(:user_organisation, user: user, organisation: List.first(user.owned_organisations))
      content_type = insert(:content_type, creator: user)

      d1 =
        insert(:data_template, title: "First Template", creator: user, content_type: content_type)

      d2 =
        insert(:data_template,
          title: "Second Template",
          creator: user,
          content_type: content_type
        )

      data_template_index =
        Document.data_templates_index_of_an_organisation(
          user,
          %{
            "title" => "does not exist",
            page_number: 1
          }
        )

      refute data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d1.title

      refute data_template_index.entries
             |> Enum.map(fn x -> x.title end)
             |> List.to_string() =~
               d2.title
    end
  end

  describe "get_data_template/2" do
    test "get data_template returns the data_template data" do
      user = insert(:user_with_organisation)

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      data_template = insert(:data_template, creator: user, content_type: content_type)
      d_data_template = Document.get_data_template(user, data_template.id)
      assert d_data_template.title == data_template.title
      assert d_data_template.title_template == data_template.title_template
      assert d_data_template.data == data_template.data
      assert d_data_template.serialized == data_template.serialized
    end
  end

  describe "show_data_template/2" do
    # TODO update test for preloading field and field type in content type
    test "show data_template returns the data_template data and preloads creator and content type" do
      user = insert(:user_with_organisation)

      content_type =
        insert(:content_type, creator: user, organisation: List.first(user.owned_organisations))

      data_template = insert(:data_template, creator: user, content_type: content_type)
      d_data_template = Document.show_data_template(user, data_template.id)
      assert d_data_template.title == data_template.title
      assert d_data_template.title_template == data_template.title_template
      assert d_data_template.data == data_template.data
      assert d_data_template.serialized == data_template.serialized
      assert d_data_template.content_type.name == content_type.name
      assert d_data_template.creator.name == user.name
    end
  end

  describe "update_data_template/2" do
    test "updates data_template on valid attrs" do
      data_template = insert(:data_template)

      data_template = Document.update_data_template(data_template, @valid_data_template_attrs)

      assert data_template.title == @valid_data_template_attrs["title"]
      assert data_template.title_template == @valid_data_template_attrs["title_template"]
      assert data_template.data == @valid_data_template_attrs["data"]
      assert data_template.serialized == @valid_data_template_attrs["serialized"]
    end

    test "does not update data_template on invalid attrs" do
      data_template = insert(:data_template)

      {:error, changeset} =
        Document.update_data_template(data_template, @invalid_data_template_attrs)

      assert %{
               title: ["can't be blank"],
               title_template: ["can't be blank"],
               data: ["can't be blank"]
             } ==
               errors_on(changeset)
    end
  end

  describe "delete_data_template/1" do
    test "deletes the data_template data" do
      data_template = insert(:data_template)
      {:ok, _data_template} = Document.delete_data_template(data_template)

      refute Repo.get(DataTemplate, data_template.id)
    end
  end

  describe "create_asset/2" do
    test "creates an asset on valid attributes" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      params = Map.put(@valid_asset_attrs, "organisation_id", organisation.id)

      {:ok, asset} = Assets.create_asset(user, params)

      assert asset.id
      assert asset.name == params["name"]
      assert asset.type == params["type"]
      assert asset.organisation_id == params["organisation_id"]
      assert asset.file.file_name == params["file"].filename
    end

    test "create asset with name formatting with valid data" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      params =
        Map.merge(@valid_asset_attrs, %{
          "file" => %Plug.Upload{
            filename: "wraft invoice.pdf",
            content_type: "application/pdf",
            path: "test/helper/wraft invoice.pdf"
          }
        })

      {:ok, asset} = Assets.create_asset(user, params)

      assert asset.id
      assert asset.name == params["name"]
      assert asset.file.file_name == "wraft-invoice.pdf"
    end

    test "only pdf files allowed for asset of layout type" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      params = Map.merge(@valid_asset_attrs, %{"organisation_id" => organisation.id})
      assert {:ok, %Asset{id: <<_::288>>}} = Assets.create_asset(user, params)

      uploader = %Plug.Upload{
        content_type: "image/png",
        filename: "avatar.png",
        path: "priv/static/images/avatar.png"
      }

      params = Map.merge(params, %{"file" => uploader})

      {:error, %Ecto.Changeset{errors: [file: {"invalid file type", _}]}} =
        Assets.create_asset(user, params)
    end

    test "only font files allowed for asset of theme type" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      uploader = %Plug.Upload{
        content_type: "font/ttf",
        filename: "Roboto-Regular.ttf",
        path: "priv/wraft_files/Roboto/Roboto-Regular.ttf"
      }

      params =
        Map.merge(
          @valid_asset_attrs,
          %{"organisation_id" => organisation.id, "file" => uploader, "type" => "theme"}
        )

      assert {:ok, %Asset{id: <<_::288>>}} = Assets.create_asset(user, params)

      params =
        Map.merge(@valid_asset_attrs, %{"organisation_id" => organisation.id, "type" => "theme"})

      {:error, %Ecto.Changeset{errors: [file: {"invalid file type", _}]}} =
        Assets.create_asset(user, params)
    end

    test "returns error on invalid attrs" do
      user = insert(:user_with_organisation)
      {:error, changeset} = Assets.create_asset(user, @invalid_attrs)

      assert %{name: ["can't be blank"], type: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "asset_index/2" do
    test "asset index lists the asset data" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      a1 = insert(:asset, creator: user, organisation: organisation)
      a2 = insert(:asset, creator: user, organisation: organisation)
      params = %{page_number: 1}
      asset_index = Assets.asset_index(user, params)

      assert asset_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ a1.name

      assert asset_index.entries
             |> Enum.map(fn x -> x.name end)
             |> List.to_string() =~ a2.name
    end
  end

  describe "get_asset/2" do
    test "get asset returns the asset data" do
      user = insert(:user_with_organisation)
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))
      a_asset = Assets.get_asset(asset.id, user)
      assert a_asset.name == asset.name
    end
  end

  describe "show_asset/2" do
    test "show asset returns the asset data and preloads" do
      user = insert(:user_with_organisation)
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))
      a_asset = Assets.show_asset(asset.id, user)
      assert a_asset.name == asset.name
      assert a_asset.creator.name == user.name
    end
  end

  describe "update_asset/2" do
    test "update asset on valid attrs" do
      # file uploading is throwing errors
      asset = insert(:asset)
      {:ok, asset} = Assets.update_asset(asset, @valid_asset_attrs)

      assert asset.name == @valid_asset_attrs["name"]
    end

    test "update asset on invalid attrs" do
      user = insert(:user)
      asset = insert(:asset, creator: user)

      count_before =
        Asset
        |> Repo.all()
        |> length()

      {:error, changeset} = Assets.update_asset(asset, %{name: nil, file: nil})

      count_after =
        Asset
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert %{name: ["can't be blank"], file: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "delete_asset/1" do
    test "delete asset deletes the asset data" do
      asset = insert(:asset)
      {:ok, _} = Assets.delete_asset(asset)

      refute Repo.get(Asset, asset.id)
    end
  end

  describe "preload_asset/1" do
    test "preload_asset" do
      layout = insert(:layout)
      preload_assets = Assets.preload_asset(layout)

      assert is_list(layout.assets) == false
      assert is_list(preload_assets.assets) == true
    end
  end

  # describe "build_doc/2" do
  #   test "build document" do
  #     instance = insert(:instance)

  #     {:ok, _asset} =
  #       Document.update_asset(
  #         insert(:asset),
  #         %{"file" => %Plug.Upload{filename: "invoice.pdf", path: "test/helper/invoice.pdf"}}
  #       )

  #     layout = insert(:layout)
  #     layout = Layout |> Repo.get(layout.id) |> Repo.preload(:assets)
  #     build_doc = Document.build_doc(instance, layout)

  #     assert is_tuple(build_doc)
  #     # assert tuple_size(build_doc) = 2
  #   end
  # end

  describe "add_build_history" do
    test "add_build_history/3 Insert the build history of the given instance." do
      params =
        :build_history
        |> insert()
        |> Map.from_struct()

      instance = insert(:instance)
      user = insert(:user)

      count_before =
        History
        |> Repo.all()
        |> length()

      add_build_history = Document.add_build_history(user, instance, params)

      count_after =
        History
        |> Repo.all()
        |> length()

      changeset = History.changeset(%History{}, params)

      assert changeset.valid?
      assert is_struct(add_build_history) == true
      assert is_struct(add_build_history.content.build_histories) == true
      assert count_before + 1 == count_after
    end

    test "Same as add_build_history/3, but creator will not be stored." do
      params =
        :build_history
        |> insert()
        |> Map.from_struct()

      instance = insert(:instance)

      count_before =
        History
        |> Repo.all()
        |> length()

      add_build_history = Document.add_build_history(instance, params)

      count_after =
        History
        |> Repo.all()
        |> length()

      assert is_struct(add_build_history) == true
      assert count_before + 1 == count_after
    end
  end

  describe "create_block/2" do
    test "creates block with valid params" do
      block = string_params_for(:block)
      user = insert(:user_with_organisation)
      created_block = Document.create_block(user, block)

      assert is_struct(created_block)
      refute is_nil(created_block.dataset)
      assert created_block.name == block["name"]
    end

    test "returns error changeset with invalid params" do
      user = insert(:user_with_organisation)
      assert {:error, %Ecto.Changeset{}} = Document.create_block(user, %{})
    end
  end

  describe "get_block/2" do
    test "get block by its ID" do
      user = insert(:user_with_organisation)
      block = insert(:block, organisation: List.first(user.owned_organisations))
      get_block = Document.get_block(block.id, user)

      assert is_struct(get_block)
      refute is_nil(get_block.dataset)
      assert get_block.name =~ ~r/([a-z]|[A-Z])/
    end
  end

  describe "update_block/2" do
    test "update block" do
      block = insert(:block)
      params = %{name: "new_name", api_route: "new/route"}
      update_block = Document.update_block(block, params)

      assert is_struct(update_block)
      assert update_block.api_route =~ "new/route"
      refute block.name == update_block.name
    end
  end

  describe "delete_block/1" do
    test "delete block" do
      block = insert(:block)

      count_before =
        Block
        |> Repo.all()
        |> length()

      _delete_block = Document.delete_block(block)

      count_after =
        Block
        |> Repo.all()
        |> length()

      assert count_before - 1 == count_after
    end
  end

  describe "generate_chart/1" do
    # it has to test with real data
    test "Function to generate charts from diffrent endpoints as per input example api: https://quickchart.io/chart/create" do
      block =
        :block
        |> insert()
        |> Map.from_struct()

      # bb = %{"dataset" => "dataset", "api_route" => "api_route", "endpoint" => "blocks_api"}
      generate_chart = Document.generate_chart(block)
      assert is_map(generate_chart)
    end
  end

  describe "generate_tex_chart/1" do
    test "Generate tex code for the chart" do
      # data = %{"dataset" => %{}, "btype" => "gantt"}
      data2 = %{"dataset" => @update_valid_attrs["dataset"]}

      dd = Document.generate_tex_chart(data2)

      refute is_nil(dd)
      assert dd =~ ~r/(pie)/
    end
  end

  describe "create_field_type/2" do
    test "Create a field type" do
      params = string_params_with_assocs(:field_type)

      [%{"error_message" => error_message, "validation" => %{"rule" => rule, "value" => value}}] =
        params["validations"]

      user = insert(:user)

      assert {:ok, field_type} = Document.create_field_type(user, params)
      assert field_type.id
      assert field_type.name == params["name"]
      assert field_type.description == params["description"]

      assert [
               %Validation{
                 id: _,
                 validation: %{"rule" => ^rule, "value" => ^value},
                 error_message: ^error_message
               }
             ] = field_type.validations
    end

    test "check unique name constraint" do
      user = insert(:user)
      params = string_params_with_assocs(:field_type)

      assert {:ok, _field_type} = Document.create_field_type(user, params)
      assert {:error, _error_msg} = Document.create_field_type(user, params)
    end
  end

  describe "field_type_index/1" do
    test "Index of all field types." do
      type_index = Repo.paginate(Document.field_type_index())

      refute is_nil(type_index)
      assert Map.has_key?(type_index, :entries)
      assert Map.has_key?(type_index, :page_size)
      assert Map.has_key?(type_index, :page_number)
    end
  end

  describe "get_field_type/1" do
    test "Get a field type from its UUID" do
      field_type = insert(:field_type)
      get_field_type = Document.get_field_type(field_type.id)

      assert get_field_type.id == field_type.id
      assert get_field_type.name == field_type.name
    end

    test "test with invalid UUID" do
      assert {:error, :fake} = Document.get_field_type("invalid")
    end
  end

  describe "update_field_type/2" do
    test "update_field_type" do
      field_type = insert(:field_type)

      new_values = %{
        name: "new",
        description: "new desc",
        validations: [
          %{validation: %{"rule" => "max_length", "value" => 2}, error_message: "2 letters tops"}
        ]
      }

      assert {:ok, updated_field_type} = Document.update_field_type(field_type, new_values)

      assert updated_field_type.name == new_values.name
      assert updated_field_type.description == new_values.description

      assert [
               %Validation{
                 validation: %{"rule" => "max_length", "value" => 2},
                 error_message: "2 letters tops"
               }
             ] = updated_field_type.validations
    end
  end

  describe "delete_field_type/1" do
    test "delete_field_type" do
      f_type = insert(:field_type)
      f_type2 = insert(:field_type)

      count_before =
        FieldType
        |> Repo.all()
        |> length()

      _delete_field_type = Document.delete_field_type(f_type)

      count_after =
        FieldType
        |> Repo.all()
        |> length()

      assert {:ok, _struct} = Document.delete_field_type(f_type2)
      assert count_before - 1 == count_after
    end
  end

  describe "create_comment/2" do
    test "create comment on valid attributes" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      instance = insert(:instance, creator: user)

      params =
        Map.merge(
          @valid_comment_attrs,
          %{
            "master_id" => instance.id,
            "organisation_id" => organisation.id
          }
        )

      count_before =
        Comment
        |> Repo.all()
        |> length()

      comment = Comments.create_comment(user, params)

      assert count_before + 1 ==
               Comment
               |> Repo.all()
               |> length()

      assert comment.comment == @valid_comment_attrs["comment"]
      assert comment.is_parent == @valid_comment_attrs["is_parent"]
      assert comment.master == @valid_comment_attrs["master"]
      assert comment.master_id == instance.id
      assert comment.organisation_id == organisation.id
    end

    test "create comment on invalid attrs" do
      user = insert(:user_with_organisation)

      count_before =
        Comment
        |> Repo.all()
        |> length()

      {:error, changeset} = Comments.create_comment(user, @invalid_attrs)

      count_after =
        Comment
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               comment: ["can't be blank"],
               is_parent: ["can't be blank"],
               master: ["can't be blank"],
               master_id: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "get_comment/2" do
    test "get comment returns the comment data" do
      user = insert(:user_with_organisation)
      comment = insert(:comment, user: user, organisation: List.first(user.owned_organisations))
      c_comment = Comments.get_comment(comment.id, user)
      assert c_comment.comment == comment.comment
      assert c_comment.is_parent == comment.is_parent
      assert c_comment.master == comment.master
      assert c_comment.master_id == comment.master_id
    end
  end

  describe "show_comment/2" do
    test "show comment returns the comment data and preloads user and profile" do
      user = insert(:user_with_organisation)
      comment = insert(:comment, user: user, organisation: List.first(user.owned_organisations))
      c_comment = Comments.show_comment(comment.id, user)
      assert c_comment.comment == comment.comment
      assert c_comment.is_parent == comment.is_parent
      assert c_comment.master == comment.master
      assert c_comment.master_id == comment.master_id
      assert c_comment.user.id == user.id
    end
  end

  describe "update_comment/2" do
    test "update comment on invalid attrs" do
      user = insert(:user)
      comment = insert(:comment, user: user)

      count_before =
        Comment
        |> Repo.all()
        |> length()

      {:error, changeset} = Comments.update_comment(comment, @invalid_comment_attrs)

      count_after =
        Comment
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               comment: ["can't be blank"],
               is_parent: ["can't be blank"],
               master: ["can't be blank"],
               master_id: ["can't be blank"],
               organisation_id: ["can't be blank"]
             } == errors_on(changeset)
    end

    test "update comment on valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      instance = insert(:instance, creator: user)

      params =
        Map.merge(
          @valid_comment_attrs,
          %{
            "master_id" => instance.id,
            "organisation_id" => organisation.id
          }
        )

      comment = insert(:comment, user: user, master_id: instance.id)

      count_before =
        Comment
        |> Repo.all()
        |> length()

      comment = Comments.update_comment(comment, params)

      count_after =
        Comment
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert comment.comment == @valid_comment_attrs["comment"]
      assert comment.is_parent == @valid_comment_attrs["is_parent"]
      assert comment.master == @valid_comment_attrs["master"]
      assert comment.master_id == instance.id
      assert comment.organisation_id == organisation.id
    end
  end

  describe "comment_index/2" do
    test "comment index lists the comment data" do
      user = insert(:user_with_organisation)
      instance = insert(:instance, creator: user)
      [organisation] = user.owned_organisations
      c1 = insert(:comment, user: user, organisation: organisation, master_id: instance.id)
      c2 = insert(:comment, user: user, organisation: organisation, master_id: instance.id)

      comment_index =
        Comments.comment_index(user, %{"page_number" => 1, "master_id" => instance.id})

      assert comment_index.entries
             |> Enum.map(fn x -> x.comment end)
             |> List.to_string() =~
               c1.comment

      assert comment_index.entries
             |> Enum.map(fn x -> x.comment end)
             |> List.to_string() =~
               c2.comment
    end
  end

  describe "delete_comment/1" do
    test "delete comment deletes the comment data" do
      user = insert(:user)
      comment = insert(:comment, user: user)

      count_before =
        Comment
        |> Repo.all()
        |> length()

      {:ok, c_comment} = Comments.delete_comment(comment)

      count_after =
        Comment
        |> Repo.all()
        |> length()

      assert count_before - 1 == count_after
      assert c_comment.comment == comment.comment
      assert c_comment.is_parent == comment.is_parent
      assert c_comment.master == comment.master
    end
  end

  describe "create_pipeline/2" do
    test "creates pipeline with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "name" => "pipeline",
        "api_route" => "www.crm.com",
        "source" => "WraftForms",
        "source_id" => "82850951-ab5d-40d3-89ce-40b321d63b81",
        "organisation_id" => organisation.id,
        "stages" => [
          %{
            "content_type_id" => c_type.id,
            "data_template_id" => d_temp.id
          }
        ]
      }

      pipeline = Document.create_pipeline(user, attrs)

      [%{content_type: content_type, data_template: data_template}] = pipeline.stages

      assert pipeline.name == "pipeline"
      assert pipeline.api_route == "www.crm.com"
      assert pipeline.source == "WraftForms"
      assert pipeline.source_id == "82850951-ab5d-40d3-89ce-40b321d63b81"
      assert content_type.name == c_type.name
      assert data_template.title == d_temp.title
    end

    test "returns error with invalid attrs" do
      user = insert(:user_with_organisation)
      {:error, changeset} = Document.create_pipeline(user, %{})
      assert %{name: ["can't be blank"], api_route: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "create_pipe_stage/3" do
    test "creates pipe stage with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      {:ok, stage} = Document.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
      assert stage.content_type_id == c_type.id
      assert stage.data_template_id == d_temp.id
      assert stage.pipeline_id == pipeline.id
      assert stage.creator_id == user.id
    end

    test "returns unique constraint error with same pipeline and data template ID" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations

      pipeline = insert(:pipeline, organisation: organisation)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)
      insert(:pipe_stage, pipeline: pipeline, content_type: c_type, data_template: d_temp)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert %{data_template_id: ["Already added.!"]} == errors_on(changeset)
    end

    test "returns nil with non-existent UUIDs of datas" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)

      attrs = %{
        "state_id" => Ecto.UUID.generate(),
        "content_type_id" => Ecto.UUID.generate(),
        "data_template_id" => Ecto.UUID.generate()
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      stage = Document.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert stage == nil
    end

    test "returns nil with wrong data" do
      user = insert(:user)
      pipeline = insert(:pipeline)

      attrs = %{"state_id" => 1, "content_type_id" => 2, "data_template_id" => 3}

      count_before =
        Stage
        |> Repo.all()
        |> length()

      stage = Document.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert stage == nil
    end

    test "returns nil when all required datas are not given" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      state = insert(:state)
      attrs = %{"state_id" => state.id}

      count_before =
        Stage
        |> Repo.all()
        |> length()

      stage = Document.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert stage == nil
    end

    test "returns nil when given datas does not belong to current user's organsation" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)
      state = insert(:state)

      attrs = %{
        "state_id" => state.id,
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      count_before =
        Stage
        |> Repo.all()
        |> length()

      response = Document.create_pipe_stage(user, pipeline, attrs)

      count_after =
        Stage
        |> Repo.all()
        |> length()

      assert count_before == count_after
      assert response == nil
    end
  end

  describe "pipeline_index/2" do
    test "returns list of pipelines in the users organisation only" do
      user = insert(:user_with_organisation)
      pipeline1 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline2 = insert(:pipeline)
      %{entries: pipelines} = Document.pipeline_index(user, %{})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert pipeline_names =~ pipeline1.name
      refute pipeline_names =~ pipeline2.name
    end

    test "returns nil with invalid attrs" do
      response = Document.pipeline_index(nil, %{})
      assert response == nil
    end

    test "pipeline index lists the pipeline data" do
      user = insert(:user_with_organisation)
      pipeline1 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline2 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      %{entries: pipelines} = Document.pipeline_index(user, %{})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert pipeline_names =~ pipeline1.name
      assert pipeline_names =~ pipeline2.name
    end

    test "filters by name" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Document.pipeline_index(user, %{"name" => "First"})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      assert pipeline_names =~ pipeline1.name
      refute pipeline_names =~ pipeline2.name
    end

    test "returns an empty list when there are no matches for the name keyword" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Document.pipeline_index(user, %{"name" => "Does Not Exist"})

      pipeline_names =
        pipelines
        |> Enum.map(fn x -> x.name end)
        |> List.to_string()

      refute pipeline_names =~ pipeline1.name
      refute pipeline_names =~ pipeline2.name
    end

    test "sorts by name in ascending order when sort key is name" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Document.pipeline_index(user, %{"sort" => "name"})

      assert List.first(pipelines).name == pipeline1.name
      assert List.last(pipelines).name == pipeline2.name
    end

    test "sorts by name in descending order when sort key is name_desc" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Document.pipeline_index(user, %{"sort" => "name_desc"})

      assert List.first(pipelines).name == pipeline2.name
      assert List.last(pipelines).name == pipeline1.name
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:56:34],
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:57:34],
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Document.pipeline_index(user, %{"sort" => "inserted_at"})

      assert List.first(pipelines).name == pipeline1.name
      assert List.last(pipelines).name == pipeline2.name
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)

      pipeline1 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:56:34],
          organisation: List.first(user.owned_organisations)
        )

      pipeline2 =
        insert(
          :pipeline,
          inserted_at: ~N[2023-04-18 11:57:34],
          organisation: List.first(user.owned_organisations)
        )

      %{entries: pipelines} = Document.pipeline_index(user, %{"sort" => "inserted_at_desc"})

      assert List.first(pipelines).name == pipeline2.name
      assert List.last(pipelines).name == pipeline1.name
    end
  end

  describe "create_pipeline_job/1" do
    test "Creates a background job to run a pipeline" do
      trigger_history = insert(:trigger_history)
      assert {:ok, _dd} = Document.create_pipeline_job(trigger_history)
    end
  end

  # describe "bulk_doc_build/6" do
  #   test "Bulk build function" do
  #     user = insert(:user)
  #     c_type = insert(:content_type)
  #     state = insert(:state)
  #     d_temp = insert(:data_template)
  #     # k = Faker.Person.first_name()
  #     v = Faker.Person.last_name()
  #     map = %{"hey" => v}
  #     path = "/home/functionary/Downloads/sample4.csv"
  #     bulk_doc_build = Document.bulk_doc_build(user, c_type, state, d_temp, map, path)
  #     IO.inspect(bulk_doc_build)
  #   end
  # end

  describe "do_create_instance_params/2" do
    test "Generate params to create instance." do
      k = Faker.Person.first_name()
      v = Faker.Person.last_name()
      map = %{k => v}
      d_temp = insert(:data_template)

      assert %{"raw" => _raw, "serialized" => ss} =
               Document.do_create_instance_params(map, d_temp)

      assert is_map(ss)
      assert %{"title" => _} = ss
    end
  end

  # describe "bulk_build" do
  #   test "bulk_buil/2, Same as bulk_buil/3, but does not store the creator in build history." do
  #     instance = insert(:instance)

  #     {:ok, _asset} =
  #       Document.update_asset(
  #         insert(:asset),
  #         %{"file" => %Plug.Upload{filename: "invoice.pdf", path: "test/helper/invoice.pdf"}}
  #       )

  #     layout = insert(:layout)
  #     layout = Layout |> Repo.get(layout.id) |> Repo.preload(:assets)
  #     _build_doc = Document.build_doc(instance, layout)

  #     assert {_, exit_code} = bulk_build = Document.bulk_build(instance, layout)
  #     assert is_nil(bulk_build) == false
  #     assert is_number(exit_code)
  #   end

  #   test "bulk_build/3, Builds the doc using `build_doc/2`.
  #     Here we also records the build history using `add_build_history/3`." do
  #     instance = insert(:instance)

  #     {:ok, _asset} =
  #       Document.update_asset(
  #         insert(:asset),
  #         %{"file" => %Plug.Upload{filename: "invoice.pdf", path: "test/helper/invoice.pdf"}}
  #       )

  #     layout = insert(:layout)
  #     layout = Layout |> Repo.get(layout.id) |> Repo.preload(:assets)
  #     _build_doc = Document.build_doc(instance, layout)
  #     user = insert(:user)

  #     assert {_, exit_code} = bulk_build = Document.bulk_build(user, instance, layout)
  #     assert is_nil(bulk_build) == false
  #     assert is_number(exit_code)
  #   end
  # end

  describe "get_pipeline/2" do
    test "returns the pipeline in the user's organisation with given id" do
      user = insert(:user_with_organisation)
      pipe = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline = Document.get_pipeline(user, pipe.id)
      assert pipeline.name == pipe.name
      assert pipeline.id == pipe.id
    end

    test "returns nil when pipeline does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)
      response = Document.get_pipeline(user, pipeline.id)
      assert response == nil
    end

    test "returns nil for non existent pipeline" do
      user = insert(:user_with_organisation)
      response = Document.get_pipeline(user, Ecto.UUID.generate())
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Document.get_pipeline(nil, Ecto.UUID.generate())
      assert response == nil
    end
  end

  describe "show_pipeline/2" do
    test "returns the pipeline in the user's organisation with given id" do
      user = insert(:user_with_organisation)
      pipe = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline = Document.show_pipeline(user, pipe.id)
      assert pipeline.name == pipe.name
      assert pipeline.id == pipe.id
    end

    test "returns nil when pipeline does not belong to the user's organisation" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline)
      response = Document.show_pipeline(user, pipeline.id)
      assert response == nil
    end

    test "returns nil for non existent pipeline" do
      user = insert(:user_with_organisation)
      response = Document.show_pipeline(user, Ecto.UUID.generate())
      assert response == nil
    end

    test "returns nil for invalid data" do
      response = Document.show_pipeline(nil, Ecto.UUID.generate())
      assert response == nil
    end
  end

  describe "pipeline_update/3" do
    test "updates pipeline with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "name" => "pipeline",
        "api_route" => "www.crm.com",
        "stages" => [
          %{
            "content_type_id" => c_type.id,
            "data_template_id" => d_temp.id
          }
        ]
      }

      pipeline = Document.pipeline_update(pipeline, user, attrs)
      [stage] = pipeline.stages
      assert pipeline.name == "pipeline"
      assert pipeline.api_route == "www.crm.com"
      assert stage.content_type.name == c_type.name
      assert stage.data_template.title == d_temp.title
    end

    test "returns error with invalid attrs" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      {:error, changeset} = Document.pipeline_update(pipeline, user, %{name: ""})
      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end

    test "returns nil with wrong data" do
      response = Document.pipeline_update(nil, nil, %{})
      assert response == nil
    end
  end

  describe "delete_pipeline/1" do
    test "deletes pipeline with correct data" do
      pipeline = insert(:pipeline)
      {:ok, _pipeline} = Document.delete_pipeline(pipeline)

      refute Repo.get(Pipeline, pipeline.id)
    end

    test "returns nil with invalid data" do
      assert nil == Document.delete_pipeline(nil)
    end
  end

  describe "get_pipe_stage/2" do
    test "returns the pipe stage in the user's organisation with valid IDs and user struct" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      stage = insert(:pipe_stage, pipeline: pipeline)
      response = Document.get_pipe_stage(user, stage.id)
      assert response.pipeline_id == pipeline.id
      assert response.id == stage.id
    end

    test "returns nil when stage does not belong to user's organisation" do
      user = insert(:user_with_organisation)
      stage = insert(:pipe_stage)
      response = Document.get_pipe_stage(user, stage.id)
      assert response == nil
    end

    test "returns nil with non-existent IDs" do
      user = insert(:user_with_organisation)
      response = Document.get_pipe_stage(user, Ecto.UUID.generate())
      assert response == nil
    end

    test "returns nil invalid data" do
      response = Document.get_pipe_stage(nil, Ecto.UUID.generate())
      assert response == nil
    end
  end

  describe "update_pipe_stage/3" do
    test "updates pipe stage with valid attrs" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      state = insert(:state, organisation: organisation)
      stage = insert(:pipe_stage, state: state)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      {:ok, updated_stage} = Document.update_pipe_stage(user, stage, attrs)

      assert updated_stage.id == stage.id
      assert updated_stage.content_type_id == c_type.id
      assert updated_stage.data_template_id == d_temp.id
      assert updated_stage.state_id == state.id
    end

    test "returns unique constraint error when a stage is updated with same pipeline and content type ID of another existing stage" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      pipeline = insert(:pipeline)
      c_type = insert(:content_type, organisation: organisation)
      d_temp = insert(:data_template, content_type: c_type)
      insert(:pipe_stage, pipeline: pipeline, data_template: d_temp, content_type: c_type)
      stage = insert(:pipe_stage, pipeline: pipeline, content_type: c_type)

      attrs = %{
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      {:error, changeset} = Document.update_pipe_stage(user, stage, attrs)

      assert %{data_template_id: ["Already added.!"]} == errors_on(changeset)
    end

    test "returns nil with non-existent UUIDs of datas" do
      user = insert(:user_with_organisation)
      stage = insert(:pipe_stage)

      attrs = %{
        "state_id" => Ecto.UUID.generate(),
        "content_type_id" => Ecto.UUID.generate(),
        "data_template_id" => Ecto.UUID.generate()
      }

      stage = Document.update_pipe_stage(user, stage, attrs)

      assert stage == nil
    end

    test "returns nil with wrong data" do
      user = insert(:user)
      stage = insert(:pipe_stage)
      attrs = %{"state_id" => 1, "content_type_id" => 2, "data_template_id" => 3}
      stage = Document.update_pipe_stage(user, stage, attrs)

      assert stage == nil
    end

    test "returns nil when all required datas are not given" do
      user = insert(:user)
      stage = insert(:pipe_stage)
      state = insert(:state)
      attrs = %{"state_id" => state.id}

      stage = Document.update_pipe_stage(user, stage, attrs)

      assert stage == nil
    end

    test "returns nil when given datas does not belong to current user's organsation" do
      user = insert(:user_with_organisation)
      stage = insert(:pipe_stage)
      c_type = insert(:content_type)
      d_temp = insert(:data_template)
      state = insert(:state)

      attrs = %{
        "state_id" => state.id,
        "content_type_id" => c_type.id,
        "data_template_id" => d_temp.id
      }

      response = Document.update_pipe_stage(user, stage, attrs)

      assert response == nil
    end
  end

  describe "delete_pipe_stage/1" do
    test "deletes stage with correct data" do
      stage = insert(:pipe_stage)
      {:ok, _stage} = Document.delete_pipe_stage(stage)

      refute Repo.get(Stage, stage.id)
    end

    test "returns nil with invalid data" do
      assert nil == Document.delete_pipe_stage(nil)
    end
  end

  describe "preload_stage_details/1" do
    test "preloads the details of a stage" do
      stage = insert(:pipe_stage)
      preloaded_stage = Document.preload_stage_details(stage)
      assert preloaded_stage.content_type.name == stage.content_type.name
      assert preloaded_stage.pipeline.name == stage.pipeline.name
      assert preloaded_stage.state.state == stage.state.state
      assert preloaded_stage.data_template.title == stage.data_template.title
    end
  end

  describe "create_trigger_history/3" do
    test "creates trigger history with valid attrs" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      data = %{name: "John Doe"}
      state = TriggerHistory.states()[:enqued]

      count_before =
        TriggerHistory
        |> Repo.all()
        |> length

      {:ok, trigger} = Document.create_trigger_history(user, pipeline, data)

      count_after =
        TriggerHistory
        |> Repo.all()
        |> length

      assert count_before + 1 == count_after
      assert trigger.data == %{name: "John Doe"}
      assert trigger.pipeline_id == pipeline.id
      assert trigger.creator_id == user.id
      assert trigger.state == state
    end

    test "returns error with invalid attrs" do
      user = insert(:user)
      pipeline = insert(:pipeline)
      data = "wrong type"

      count_before =
        TriggerHistory
        |> Repo.all()
        |> length

      {:error, changeset} = Document.create_trigger_history(user, pipeline, data)

      count_after =
        TriggerHistory
        |> Repo.all()
        |> length

      assert count_before == count_after
      assert %{data: ["is invalid"]} == errors_on(changeset)
    end

    test "retruns nil with wrong data" do
      response = Document.create_trigger_history(nil, nil, %{})
      assert response == nil
    end
  end

  describe "content_type/2" do
    test "get_content_type_roles" do
      content_type = insert(:content_type)

      response = Document.get_content_type_roles(content_type.id)

      assert response.name == content_type.name
    end

    test "get_content_type_under_roles" do
      role = insert(:role)

      response = Document.get_content_type_under_roles(role.id)

      assert response.name == role.name
    end

    test "get_content_type" do
      content_type = insert(:content_type)

      response = Document.get_content_type(content_type.id)

      assert response.name == content_type.name
    end
  end

  describe "delete_role_of_the_content_type/1" do
    test "delete_role_of_the_content_type" do
      role = insert(:role)

      before_role_count =
        Role
        |> Repo.all()
        |> length()

      _response = Document.delete_role_of_the_content_type(role)

      after_role_count =
        Role
        |> Repo.all()
        |> length()

      assert after_role_count == before_role_count - 1
    end
  end

  describe "content_type_and_role/2" do
    test "get_role_of_content_type" do
      role = insert(:role)
      content_type = insert(:content_type)

      response = Document.get_role_of_content_type(role.id, content_type.id)

      assert response.name == role.name
    end

    test "get_content_type_role" do
      role = insert(:role)
      content_type = insert(:content_type)

      response = Document.get_content_type_role(content_type.id, role.id)

      assert response.name == content_type.name
    end
  end

  @tag :cict
  describe "create_instance_content_types" do
    test "creates relations for approval systems of content type" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      flow = insert(:flow, organisation: organisation)
      insert(:approval_system, flow: flow)
      insert(:approval_system, flow: flow)
      content_type = insert(:content_type, flow: flow, organisation: organisation)
      instance = insert(:instance, content_type: content_type)

      count_before =
        InstanceApprovalSystem
        |> Repo.all()
        |> length()

      Document.create_instance_approval_systems(content_type, instance)

      count_after =
        InstanceApprovalSystem
        |> Repo.all()
        |> length()

      assert count_before + 2 == count_after
    end
  end

  @tag :version
  describe "create_version/3" do
    test "create version for valid attrs" do
      user = insert(:user)
      instance = insert(:instance)

      count_before =
        Version
        |> Repo.all()
        |> length()

      {:ok, version} = Document.create_version(user, instance, %{naration: "New year edition"})

      count_after =
        Version
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after

      assert version.content_id == instance.id
    end
  end

  describe "create_collection_form" do
    test "created collection form with valid attrs" do
      user = insert(:user_with_organisation)
      params = %{"title" => "WraftDoc", "description" => "Wraft Doc"}

      count_before =
        CollectionForm
        |> Repo.all()
        |> length()

      Document.create_collection_form(user, params)

      count_after =
        CollectionForm
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
    end

    test "created collection form with invalid attrs" do
      user = insert(:user)
      params = %{}

      count_before =
        CollectionForm
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.create_collection_form(user, params)

      count_after =
        CollectionForm
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
        title: ["can't be blank"] == errors_on(changeset)
      }
    end
  end

  describe "get_collection_form" do
    test "get_collection_form with valid id" do
      user = insert(:user_with_organisation)

      collection_form =
        insert(:collection_form, organisation: List.first(user.owned_organisations))

      response = Document.get_collection_form(user, collection_form.id)

      assert response.title == collection_form.title
    end

    test "get_collection_form_with_invalid_id" do
      user = insert(:user_with_organisation)
      response = Document.get_collection_form(user, Ecto.UUID.generate())

      assert response == {:error, :invalid_id, "CollectionForm"}
    end
  end

  describe "update_collection_form" do
    test "update collection form with valid attrs" do
      user = insert(:user)

      collection_form =
        insert(:collection_form, organisation: List.first(user.owned_organisations))

      params = %{title: "WraftDoc", description: "Wraft Doc"}

      count_before =
        CollectionForm
        |> Repo.all()
        |> length()

      Document.update_collection_form(collection_form, params)

      count_after =
        CollectionForm
        |> Repo.all()
        |> length()

      assert count_before == count_after
    end

    test "update collection form with invalid attrs" do
      collection_form = insert(:collection_form)
      params = %{title: nil}

      count_before =
        CollectionForm
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.update_collection_form(collection_form, params)

      count_after =
        CollectionForm
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               title: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  test "delete_collection_form" do
    collection_form = insert(:collection_form)

    before_collection_count =
      CollectionForm
      |> Repo.all()
      |> length()

    _response = Document.delete_collection_form(collection_form)

    after_collection_count =
      CollectionForm
      |> Repo.all()
      |> length()

    assert after_collection_count == before_collection_count - 1
  end

  describe "create_collection_form_field" do
    test "created collection form field with valid attrs" do
      user = insert(:user)
      collection = insert(:collection_form, organisation: List.first(user.owned_organisations))

      param = %{
        "name" => "collection form",
        "field_type" => "string"
      }

      count_before =
        CollectionFormField
        |> Repo.all()
        |> length()

      _a = Document.create_collection_form_field(collection.id, param)

      count_after =
        CollectionFormField
        |> Repo.all()
        |> length()

      assert count_before + 1 == count_after
    end

    test "created collection form with invalid attrs" do
      user = insert(:user)

      collection_form =
        insert(:collection_form, organisation: List.first(user.owned_organisations))

      params = %{}

      count_before =
        CollectionFormField
        |> Repo.all()
        |> length()

      Document.create_collection_form_field(collection_form, params)

      count_after =
        CollectionFormField
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
        name: ["can't be blank"]
      }
    end
  end

  describe "get_collection_form_field" do
    test "get_collection_form_field with valid id" do
      user = insert(:user_with_organisation)

      collection_form =
        insert(:collection_form, organisation: List.first(user.owned_organisations))

      collection_form_field = insert(:collection_form_field, collection_form: collection_form)

      response = Document.get_collection_form_field(user, collection_form_field.id)

      assert response.name == collection_form_field.name
    end

    test "get_collection_form_with_invalid_id" do
      user = insert(:user_with_organisation)
      response = Document.get_collection_form_field(user, Ecto.UUID.generate())

      assert response == {:error, :invalid_id, "CollectionFormField"}
    end
  end

  describe "update_collection_form_field" do
    test "update collection form field with valid attrs" do
      user = insert(:user)

      collection_form =
        insert(:collection_form, organisation: List.first(user.owned_organisations))

      collection_form_field = insert(:collection_form_field, collection_form: collection_form)
      params = %{title: "WraftDoc", description: "Wraft Doc"}

      count_before =
        CollectionFormField
        |> Repo.all()
        |> length()

      Document.update_collection_form_field(collection_form_field, params)

      count_after =
        CollectionFormField
        |> Repo.all()
        |> length()

      assert count_before == count_after
    end

    test "update collection form field with invalid attrs" do
      collection_form = insert(:collection_form_field)
      params = %{name: nil}

      count_before =
        CollectionFormField
        |> Repo.all()
        |> length()

      {:error, changeset} = Document.update_collection_form_field(collection_form, params)

      count_after =
        CollectionFormField
        |> Repo.all()
        |> length()

      assert count_before == count_after

      assert %{
               name: ["can't be blank"],
               field_type: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  test "delete_collection_form_field" do
    user = insert(:user)
    collection_form = insert(:collection_form, organisation: List.first(user.owned_organisations))
    collection_form_field = insert(:collection_form_field, collection_form: collection_form)

    before_collection_count =
      CollectionFormField
      |> Repo.all()
      |> length()

    _response = Document.delete_collection_form_field(collection_form_field)

    after_collection_count =
      CollectionFormField
      |> Repo.all()
      |> length()

    assert after_collection_count == before_collection_count - 1
  end

  describe "get_trigger_histories_of_a_pipeline/2" do
    test "returns trigger history of only the given pipeline" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.get_trigger_histories_of_a_pipeline(pipeline, %{page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      assert trigger_history_ids =~ trigger_history_2.id
    end

    test "returns nil with invalid attrs" do
      trigger_history_index =
        Document.get_trigger_histories_of_a_pipeline("invalid attrs", %{page: 1})

      assert trigger_history_index == nil
    end
  end

  describe "trigger_history_index/2" do
    test "trigger history index the trigger history data" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline)

      %{entries: trigger_history_index} = Document.trigger_history_index(user, %{page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      assert trigger_history_ids =~ trigger_history_2.id
    end

    test "returns nil with invalid attrs" do
      trigger_history_index = Document.trigger_history_index("invalid attrs", %{page: 1})
      assert trigger_history_index == nil
    end

    test "returns trigger history from pipeline in user's organisation only" do
      user = insert(:user_with_organisation)
      pipeline_1 = insert(:pipeline, organisation: List.first(user.owned_organisations))
      pipeline_2 = insert(:pipeline)
      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} = Document.trigger_history_index(user, %{page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      refute trigger_history_ids =~ trigger_history_2.id
    end

    test "filter by pipeline name" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"pipeline_name" => "First", page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      refute trigger_history_ids =~ trigger_history_2.id
    end

    test "returns an empty list when there are no matches for the pipeline_name keyword" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      insert(:trigger_history, pipeline: pipeline_1)
      insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"pipeline_name" => "Does Not Exist", page: 1})

      assert [] == trigger_history_index
    end

    test "filter by status" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, state: 1, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"status" => 1, page: 1})

      trigger_history_ids =
        trigger_history_index
        |> Enum.map(fn x -> x.id end)
        |> List.to_string()

      assert trigger_history_ids =~ trigger_history_1.id
      refute trigger_history_ids =~ trigger_history_2.id
    end

    test "returns an empty list when there are no matches for the status keyword" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      insert(:trigger_history, state: 1, pipeline: pipeline)
      insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"status" => 3, page: 1})

      assert [] == trigger_history_index
    end

    test "sorts by pipeline_name in ascending order when sort key is pipeline_name" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"sort" => "pipeline_name", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_1.id
      assert List.last(trigger_history_index).id == trigger_history_2.id
    end

    test "sorts by pipeline_name in descending order when sort key is pipeline_name_desc" do
      user = insert(:user_with_organisation)

      pipeline_1 =
        insert(
          :pipeline,
          name: "First Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      pipeline_2 =
        insert(
          :pipeline,
          name: "Second Pipeline",
          organisation: List.first(user.owned_organisations)
        )

      trigger_history_1 = insert(:trigger_history, pipeline: pipeline_1)
      trigger_history_2 = insert(:trigger_history, pipeline: pipeline_2)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"sort" => "pipeline_name_desc", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_2.id
      assert List.last(trigger_history_index).id == trigger_history_1.id
    end

    test "sorts by status in ascending order when sort key is status" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, state: 1, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"sort" => "status", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_1.id
      assert List.last(trigger_history_index).id == trigger_history_2.id
    end

    test "sorts by status in descending order when sort key is status_desc" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))
      trigger_history_1 = insert(:trigger_history, state: 1, pipeline: pipeline)
      trigger_history_2 = insert(:trigger_history, state: 2, pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"sort" => "status_desc", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_2.id
      assert List.last(trigger_history_index).id == trigger_history_1.id
    end

    test "sorts by inserted_at in ascending order when sort key is inserted_at" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))

      trigger_history_1 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:56:34], pipeline: pipeline)

      trigger_history_2 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:57:34], pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"sort" => "inserted_at", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_1.id
      assert List.last(trigger_history_index).id == trigger_history_2.id
    end

    test "sorts by inserted_at in descending order when sort key is inserted_at_desc" do
      user = insert(:user_with_organisation)
      pipeline = insert(:pipeline, organisation: List.first(user.owned_organisations))

      trigger_history_1 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:56:34], pipeline: pipeline)

      trigger_history_2 =
        insert(:trigger_history, inserted_at: ~N[2023-04-18 11:57:34], pipeline: pipeline)

      %{entries: trigger_history_index} =
        Document.trigger_history_index(user, %{"sort" => "inserted_at_desc", page: 1})

      assert List.first(trigger_history_index).id == trigger_history_2.id
      assert List.last(trigger_history_index).id == trigger_history_1.id
    end
  end

  describe "create_field/2" do
    test "creates a field with valid attrs" do
      field_type = insert(:field_type)
      %{id: organisation_id} = insert(:organisation)

      params = %{
        name: "employee_name",
        meta: %{validations: [%{rule: "required", value: true}]},
        description: "Name of the employee",
        organisation_id: organisation_id
      }

      assert {:ok, %Field{id: _, name: "employee_name"} = field} =
               Document.create_field(field_type, params)

      assert field.description == params.description
      assert field.meta == params.meta
    end

    test "returns error changeset with invalid attrs" do
      field_type = insert(:field_type)
      assert {:error, %Ecto.Changeset{}} = Document.create_field(field_type, %{})
    end
  end
end
