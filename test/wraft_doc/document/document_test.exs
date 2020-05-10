defmodule WraftDoc.DocumentTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  use ExUnit.Case
  use Bamboo.Test

  alias WraftDoc.{
    Repo,
    Account.User,
    Document.Layout,
    Document.ContentType,
    Document.Engine,
    Document.Instance,
    Document.Instance.History,
    Document.Instance.Version,
    Document.Theme,
    Document.DataTemplate,
    Document.Asset,
    Document.LayoutAsset,
    Document.FieldType,
    Document.ContentTypeField,
    Document.Counter,
    Enterprise,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Document.Block,
    Document.BlockTemplate,
    Document.Comment,
    Document
  }

  @valid_layout_attrs %{
    "name" => "layout name",
    "description" => "layout description",
    "width" => 25.0,
    "height" => 44.0,
    "unit" => "cm",
    "slug" => "layout slug"
  }

  @invalid_attrs %{}

  test "create layout on valid attributes" do
    user = insert(:user)
    engine = insert(:engine)
    count_before = Layout |> Repo.all() |> length()
    layout = Document.create_layout(user, engine, @valid_layout_attrs)
    assert count_before + 1 == Layout |> Repo.all() |> length()
    assert layout.name == @valid_layout_attrs["name"]
    assert layout.description == @valid_layout_attrs["description"]
    assert layout.width == @valid_layout_attrs["width"]
    assert layout.height == @valid_layout_attrs["height"]
    assert layout.unit == @valid_layout_attrs["unit"]
    assert layout.slug == @valid_layout_attrs["slug"]
  end

  test "create layout on invalid attrs" do
    user = insert(:user)
    count_before = Layout |> Repo.all() |> length()
    engine = insert(:engine)
    {:error, changeset} = Document.create_layout(user, engine, @invalid_attrs)
    count_after = Layout |> Repo.all() |> length()
    assert count_before == count_after

    assert %{
             name: ["can't be blank"],
             description: ["can't be blank"],
             width: ["can't be blank"],
             height: ["can't be blank"],
             unit: ["can't be blank"],
             slug: ["can't be blank"]
           } == errors_on(changeset)
  end

  test "show layout shows the layout data and preloads engine crator assets data" do
    user = insert(:user)
    engine = insert(:engine)
    asset = insert(:asset)
    layout = insert(:layout, creator: user, engine: engine)
    layout_asset = insert(:layout_asset, layout: layout, asset: asset, creator: user)
    s_layout = Document.show_layout(layout.uuid)

    assert s_layout.name == layout.name
    assert s_layout.description == layout.description
    assert s_layout.creator.name == user.name
    assert s_layout.engine.name == engine.name
  end

  test "get layout returns the layout data by uuid" do
    user = insert(:user)
    layout = insert(:layout, creator: user)
    s_layout = Document.get_layout(layout.uuid)
    assert s_layout.name == layout.name
    assert s_layout.description == layout.description
    assert s_layout.width == layout.width
    assert s_layout.height == layout.height
    assert s_layout.unit == layout.unit
    assert s_layout.slug == layout.slug
  end

  test "get layout asset from its layout and assets uuids" do
    user = insert(:user)
    engine = insert(:engine)
    asset = insert(:asset)
    layout = insert(:layout, creator: user, engine: engine)
    layout_asset = insert(:layout_asset, layout: layout, asset: asset, creator: user)
    g_layout_asset = Document.get_layout_asset(layout.uuid, asset.uuid)
    assert layout_asset.uuid == g_layout_asset.uuid
  end

  test "update layout on valid attrs" do
    user = insert(:user)
    engine = insert(:engine)
    layout = insert(:layout, creator: user)
    count_before = Layout |> Repo.all() |> length()
    params = Map.put(@valid_layout_attrs, "engine_uuid", engine.uuid)

    layout = Document.update_layout(layout, user, params)
    count_after = Layout |> Repo.all() |> length()
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
    layout = insert(:layout, creator: user)
    count_before = Layout |> Repo.all() |> length()

    {:error, changeset} = Document.update_layout(layout, user, @invalid_attrs)
    count_after = Layout |> Repo.all() |> length()
    assert count_before == count_after

    assert %{
             engine_id: ["can't be blank"],
             slug: ["can't be blank"]
           } == errors_on(changeset)
  end

  test "delete layout deletes the layout and returns its data" do
    user = insert(:user)
    layout = insert(:layout)
    count_before = Layout |> Repo.all() |> length()
    {:ok, model} = Document.delete_layout(layout, user)
    count_after = Layout |> Repo.all() |> length()
    assert count_before - 1 == count_after
    assert layout.name == layout.name
    assert layout.description == layout.description
    assert layout.width == layout.width
    assert layout.height == layout.height
    assert layout.unit == layout.unit
    assert layout.slug == layout.slug
  end

  test "delete layout asset deletes a layouts asset and returns the data" do
    user = insert(:user)
    layout = insert(:layout)
    asset = insert(:asset)
    layout_asset = insert(:layout_asset, layout: layout, asset: asset, creator: user)
    count_before = LayoutAsset |> Repo.all() |> length()
    {:ok, l_asset} = Document.delete_layout_asset(layout_asset, user)
    count_after = LayoutAsset |> Repo.all() |> length()
    assert count_before - 1 == count_after
    assert l_asset.asset.name == asset.name
  end

  test "layout index returns the list of layouts" do
    user = insert(:user)
    engine = insert(:engine)
    a1 = insert(:asset)
    a2 = insert(:asset)
    l1 = insert(:layout, creator: user, organisation: user.organisation, engine: engine)
    l2 = insert(:layout, creator: user, organisation: user.organisation, engine: engine)
    la1 = insert(:layout_asset, layout: l1, asset: a1)
    la2 = insert(:layout_asset, layout: l2, asset: a2)
    layout_index = Document.layout_index(user, %{page_number: 1})

    assert layout_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ l1.name
    assert layout_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~ l2.name
  end

  # test "layout file upload with slug file uploads a file to slug" do
  #   user = insert(:user)
  #   layout = insert(:layout, creator: user)

  #   params = %{
  #     "slug_file" => %Plug.Upload{path: "test/fixtures/example.png", filename: "example.png"}
  #   }

  #   u_layout = Document.layout_files_upload(layout, params)
  #   assert u_layout.slug_file.filename == "example.png"
  # end

  # test "layout file upload with screen shot files upload a file as screenshot" do
  #   user = insert(:user)
  #   layout = insert(:layout, creator: user)

  #   params = %{
  #     "screenshot" => %Plug.Upload{path: "test/fixtures/example.png", filename: "example.png"}
  #   }

  #   u_layout = Document.layout_files_upload(layout, params)
  #   assert u_layout.screenshot.filename == "example.png"
  # end

  @valid_content_type_attrs %{
    "name" => "content_type name",
    "description" => "content_type description",
    "color" => "#fff",
    "prefix" => "OFFRE"
  }
  test "create content_type on valid attributes" do
    user = insert(:user)
    layout = insert(:layout, creator: user)
    flow = insert(:flow, creator: user)
    count_before = ContentType |> Repo.all() |> length()
    content_type = Document.create_content_type(user, layout, flow, @valid_content_type_attrs)
    count_after = ContentType |> Repo.all() |> length()
    count_before + 1 == count_after
    assert content_type.name == @valid_content_type_attrs["name"]
    assert content_type.description == @valid_content_type_attrs["description"]
    assert content_type.color == @valid_content_type_attrs["color"]
    assert content_type.prefix == @valid_content_type_attrs["prefix"]
  end

  test "create content_type on invalid attrs" do
    user = insert(:user)
    layout = insert(:layout, creator: user)
    flow = insert(:flow, creator: user)
    count_before = ContentType |> Repo.all() |> length()

    {:error, changeset} = Document.create_content_type(user, layout, flow, @invalid_attrs)
    count_after = ContentType |> Repo.all() |> length()
    assert count_before == count_after

    assert %{
             name: ["can't be blank"],
             description: ["can't be blank"],
             prefix: ["can't be blank"]
           } == errors_on(changeset)
  end

  test "content_type index lists the content_type data" do
    user = insert(:user)
    c1 = insert(:content_type, creator: user, organisation: user.organisation)
    c2 = insert(:content_type, creator: user, organisation: user.organisation)
    content_type_index = Document.content_type_index(user, %{page_number: 1})

    assert content_type_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~
             c1.name

    assert content_type_index.entries |> Enum.map(fn x -> x.name end) |> List.to_string() =~
             c2.name
  end

  test "show content_type shows the content_type data" do
    user = insert(:user)
    layout = insert(:layout, creator: user)
    flow = insert(:flow, creator: user)
    state_1 = insert(:state, flow: flow)
    state_2 = insert(:state, flow: flow)
    field_type = insert(:field_type)
    content_type = insert(:content_type, creator: user, layout: layout, flow: flow)

    content_type_field =
      insert(:content_type_field,
        content_type: content_type,
        field_type: field_type
      )

    s_content_type = Document.show_content_type(content_type.uuid)
    assert s_content_type.name == content_type.name
    assert s_content_type.description == content_type.description
    assert s_content_type.color == content_type.color
    assert s_content_type.prefix == content_type.prefix
    assert s_content_type.layout.name == layout.name
  end

  test "get content_type shows the content_type data" do
    user = insert(:user)
    content_type = insert(:content_type, creator: user)
    s_content_type = Document.get_content_type(content_type.uuid)
    assert s_content_type.name == content_type.name
    assert s_content_type.description == content_type.description
    assert s_content_type.color == content_type.color
    assert s_content_type.prefix == content_type.prefix
  end

  test "update content_type on valid attrs" do
    user = insert(:user)
    layout = insert(:layout, creator: user)
    flow = insert(:flow, creator: user)
    content_type = insert(:content_type, creator: user, layout: layout, flow: flow)
    count_before = ContentType |> Repo.all() |> length()

    params =
      Map.merge(@valid_content_type_attrs, %{
        "flow_uuid" => flow.uuid,
        "layout_uuid" => layout.uuid
      })

    content_type = Document.update_content_type(content_type, user, params)
    count_after = ContentType |> Repo.all() |> length()
    assert count_before == count_after
    assert content_type.name == @valid_content_type_attrs["name"]
    assert content_type.description == @valid_content_type_attrs["description"]
    assert content_type.color == @valid_content_type_attrs["color"]
    assert content_type.prefix == @valid_content_type_attrs["prefix"]
  end

  test "update content_type on invalid attrs" do
    user = insert(:user)
    content_type = insert(:content_type, creator: user)
    count_before = ContentType |> Repo.all() |> length()

    {:error, changeset} = Document.update_content_type(content_type, user, @invalid_attrs)
    count_after = ContentType |> Repo.all() |> length()
    assert count_before == count_after

    %{
      name: ["can't be blank"],
      description: ["can't be blank"],
      prefix: ["can't be blank"]
    } == errors_on(changeset)
  end

  test "delete content_type deletes the content_type data" do
    user = insert(:user)
    content_type = insert(:content_type)
    count_before = ContentType |> Repo.all() |> length()
    {:ok, s_content_type} = Document.delete_content_type(content_type, user)
    count_after = ContentType |> Repo.all() |> length()
    assert count_before - 1 == count_after
    assert s_content_type.name == content_type.name
    assert s_content_type.description == content_type.description
    assert s_content_type.color == content_type.color
    assert s_content_type.prefix == content_type.prefix
  end

  @valid_instance_attrs %{
    "instance_id" => "OFFR0001",
    "raw" => "instance raw",
    "serialized" => %{"body" => "body of the content", "title" => "title of the content"}
  }

  test "create instance on valid attributes and updates count of instances at counter" do
    user = insert(:user)
    content_type = insert(:content_type)
    flow = content_type.flow
    state = insert(:state, flow: flow)
    counter_count = Counter |> Repo.all() |> length()
    count_before = Instance |> Repo.all() |> length()
    instance = Document.create_instance(user, content_type, state, @valid_instance_attrs)

    count_after = Instance |> Repo.all() |> length()
    counter_count_after = Counter |> Repo.all() |> length()
    assert count_before + 1 == count_after
    assert counter_count + 1 == counter_count_after
    assert instance.raw == @valid_instance_attrs["raw"]
    assert instance.serialized == @valid_instance_attrs["serialized"]
  end

  test "create instance on invalid attrs" do
    user = insert(:user)
    count_before = Instance |> Repo.all() |> length()
    content_type = insert(:content_type)
    state = insert(:state, flow: content_type.flow)

    {:error, changeset} = Document.create_instance(user, content_type, state, @invalid_attrs)

    count_after = Instance |> Repo.all() |> length()
    assert count_before == count_after

    assert %{
             raw: ["can't be blank"]
           } == errors_on(changeset)
  end

  test "instance index lists the instance data" do
    user = insert(:user)
    content_type = insert(:content_type)
    i1 = insert(:instance, creator: user, content_type: content_type)
    i2 = insert(:instance, creator: user, content_type: content_type)
    instance_index = Document.instance_index(content_type.uuid, %{page_number: 1})

    assert instance_index.entries |> Enum.map(fn x -> x.raw end) |> List.to_string() =~
             i1.raw

    assert instance_index.entries |> Enum.map(fn x -> x.raw end) |> List.to_string() =~ i2.raw
  end

  test "instance index of an organisation lists instances under an organisation" do
    user = insert(:user)
    organisation = user.organisation
    i1 = insert(:instance, creator: user)
    i2 = insert(:instance, creator: user)

    instance_index_under_organisation =
      Document.instance_index_of_an_organisation(user, %{page_number: 1})

    assert instance_index_under_organisation.entries
           |> Enum.map(fn x -> x.instance_id end)
           |> List.to_string() =~
             i1.instance_id

    assert instance_index_under_organisation.entries
           |> Enum.map(fn x -> x.raw end)
           |> List.to_string() =~ i2.raw
  end

  test "get instance shows the instance data" do
    user = insert(:user)
    instance = insert(:instance, creator: user)
    i_instance = Document.get_instance(instance.uuid)
    assert i_instance.instance_id == instance.instance_id
    assert i_instance.raw == instance.raw
  end

  test "show instance shows and preloads creator content thype layout and state instance data" do
    user = insert(:user)
    content_type = insert(:content_type, creator: user)
    flow = content_type.flow
    state = insert(:state, flow: flow)
    instance = insert(:instance, creator: user, content_type: content_type, state: state)

    i_instance = Document.show_instance(instance.uuid)
    assert i_instance.instance_id == instance.instance_id
    assert i_instance.raw == instance.raw

    assert i_instance.creator.name == user.name
    assert i_instance.content_type.name == content_type.name
    assert i_instance.state.state == state.state
  end

  test "update instance on valid attrs and add a version data" do
    user = insert(:user)

    instance = insert(:instance, creator: user)
    count_before = Instance |> Repo.all() |> length()
    version_count_before = Version |> Repo.all() |> length()
    instance = Document.update_instance(instance, user, @valid_instance_attrs)
    version_count_after = Version |> Repo.all() |> length()
    count_after = Instance |> Repo.all() |> length()
    assert count_before == count_after
    assert version_count_before + 1 == version_count_after
    assert instance.instance_id == @valid_instance_attrs["instance_id"]
    assert instance.raw == @valid_instance_attrs["raw"]
    assert instance.serialized == @valid_instance_attrs["serialized"]
  end

  @invalid_instance_attrs %{raw: nil}
  test "update instance on invalid attrs" do
    user = insert(:user)

    instance = insert(:instance, creator: user)
    count_before = Instance |> Repo.all() |> length()

    {:error, changeset} = Document.update_instance(instance, user, @invalid_instance_attrs)

    count_after = Instance |> Repo.all() |> length()
    assert count_before == count_after

    %{raw: ["can't be blank"]} ==
      errors_on(changeset)
  end

  test "update instance state updates state of an instance to new state" do
    user = insert(:user)
    content_type = insert(:content_type, creator: user)
    pre_state = insert(:state, flow: content_type.flow)
    post_state = insert(:state, flow: content_type.flow)
    instance = insert(:instance, creator: user, content_type: content_type, state: pre_state)

    instance = Document.update_instance_state(user, instance, post_state)

    assert instance.state_id == post_state.id
  end

  describe "data_template_bulk_insert/4" do
    test "test bulk data template creation with valid data" do
      c_type = insert(:content_type)
      user = insert(:user)
      mapping = %{"Title" => "title", "TitleTemplate" => "title_template", "Data" => "data"}
      path = "test/helper/data_template_source.csv"
      count_before = DataTemplate |> Repo.all() |> length()

      data_templates =
        Document.data_template_bulk_insert(user, c_type, mapping, path)
        |> Enum.map(fn {:ok, x} -> x.title end)
        |> List.to_string()

      assert count_before + 3 == DataTemplate |> Repo.all() |> length()
      assert data_templates =~ "Title1"
      assert data_templates =~ "Title2"
      assert data_templates =~ "Title3"
    end

    test "test doesn not do bulk data template creation with invalid data" do
      count_before = DataTemplate |> Repo.all() |> length()
      response = Document.data_template_bulk_insert(nil, nil, nil, nil)
      assert count_before == DataTemplate |> Repo.all() |> length()
      assert response == {:error, :not_found}
    end
  end

  describe "create_data_template/3" do
    test "test creates data template with valid attrs" do
      user = insert(:user)
      c_type = insert(:content_type)

      params = %{
        title: "Offer letter tempalate",
        title_template: "Hi [employee], we welcome you to our [company], [address]",
        data: "Hi [employee], we welcome you to our [company], [address]"
      }

      count_before = DataTemplate |> Repo.all() |> length()
      {:ok, data_template} = Document.create_data_template(user, c_type, params)

      assert count_before + 1 == DataTemplate |> Repo.all() |> length()
      assert data_template.title == "Offer letter tempalate"

      assert data_template.title_template ==
               "Hi [employee], we welcome you to our [company], [address]"

      assert data_template.data == "Hi [employee], we welcome you to our [company], [address]"
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
      user = insert(:user)
      mapping = %{"Body" => "body", "Serialised" => "serialised", "Title" => "title"}
      path = "test/helper/block_template_source.csv"
      count_before = BlockTemplate |> Repo.all() |> length()

      block_templates =
        Document.block_template_bulk_insert(user, mapping, path)
        |> Enum.map(fn x -> x.title end)
        |> List.to_string()

      assert count_before + 3 == BlockTemplate |> Repo.all() |> length()
      assert block_templates =~ "B Temp1"
      assert block_templates =~ "B Temp2"
      assert block_templates =~ "B Temp3"
    end

    test "test doesn not do bulk block template creation with invalid data" do
      count_before = BlockTemplate |> Repo.all() |> length()
      response = Document.block_template_bulk_insert(nil, nil, nil)
      assert count_before == BlockTemplate |> Repo.all() |> length()
      assert response == {:error, :not_found}
    end
  end

  describe "create_block_template/2" do
    test "test creates block template with valid attrs" do
      user = insert(:user)

      params = %{
        title: "Introduction",
        body: "Hi [employee], we welcome you to our [company], [address]",
        serialised: "Hi [employee], we welcome you to our family"
      }

      count_before = BlockTemplate |> Repo.all() |> length()
      block_template = Document.create_block_template(user, params)

      assert count_before + 1 == BlockTemplate |> Repo.all() |> length()
      assert block_template.title == "Introduction"
      assert block_template.body == "Hi [employee], we welcome you to our [company], [address]"
      assert block_template.serialised == "Hi [employee], we welcome you to our family"
    end

    test "test does not create block template with invalid attrs" do
      user = insert(:user)
      {:error, changeset} = Document.create_block_template(user, %{})

      assert %{
               title: ["can't be blank"],
               serialised: ["can't be blank"],
               body: ["can't be blank"]
             } == errors_on(changeset)
    end
  end

  describe "insert_bulk_build_work/6" do
    test "test creates bulk build backgroung job with valid attrs" do
      user = insert(:user)
      %{uuid: c_type_id} = insert(:content_type)
      %{uuid: state_id} = insert(:state)
      %{uuid: d_temp_id} = insert(:data_template)
      mapping = %{test: "map"}
      file = Plug.Upload.random_file!("test")
      tmp_file_source = "temp/bulk_build_source/" <> file
      count_before = Oban.Job |> Repo.all() |> length()

      {:ok, job} =
        Document.insert_bulk_build_work(
          user,
          c_type_id,
          state_id,
          d_temp_id,
          mapping,
          %Plug.Upload{filename: file, path: file}
        )

      assert count_before + 1 == Oban.Job |> Repo.all() |> length()

      assert job.args == %{
               c_type_uuid: c_type_id,
               state_uuid: state_id,
               d_temp_uuid: d_temp_id,
               mapping: mapping,
               user_uuid: user.uuid,
               file: tmp_file_source
             }
    end

    test "does not create bulk build backgroung job with invalid attrs" do
      response = Document.insert_bulk_build_work(nil, nil, nil, nil, nil, nil)
      assert response == nil
    end
  end

  describe "insert_data_template_bulk_import_work/4" do
    test "test creates bulk import data template backgroung job with valid attrs" do
      %{uuid: user_id} = insert(:user)
      %{uuid: c_type_id} = insert(:content_type)
      mapping = %{test: "map"}
      file = Plug.Upload.random_file!("test")
      tmp_file_source = "temp/bulk_import_source/d_template/" <> file
      count_before = Oban.Job |> Repo.all() |> length()

      {:ok, job} =
        Document.insert_data_template_bulk_import_work(user_id, c_type_id, mapping, %Plug.Upload{
          filename: file,
          path: file
        })

      assert count_before + 1 == Oban.Job |> Repo.all() |> length()

      assert job.args == %{
               user_uuid: user_id,
               c_type_uuid: c_type_id,
               mapping: mapping,
               file: tmp_file_source
             }
    end

    test "does not create bulk import data template backgroung job with invalid attrs" do
      response = Document.insert_data_template_bulk_import_work(nil, nil, nil, nil)
      assert response == nil
    end
  end

  describe "insert_block_template_bulk_import_work/3" do
    test "test creates bulk import block template backgroung job with valid attrs" do
      %{uuid: user_id} = insert(:user)
      mapping = %{test: "map"}
      file = Plug.Upload.random_file!("test")
      tmp_file_source = "temp/bulk_import_source/b_template/" <> file
      count_before = Oban.Job |> Repo.all() |> length()

      {:ok, job} =
        Document.insert_block_template_bulk_import_work(user_id, mapping, %Plug.Upload{
          filename: file,
          path: file
        })

      assert count_before + 1 == Oban.Job |> Repo.all() |> length()
      assert job.args == %{user_uuid: user_id, mapping: mapping, file: tmp_file_source}
    end

    test "does not create bulk import block template backgroung job with invalid attrs" do
      response = Document.insert_block_template_bulk_import_work(nil, nil, nil)
      assert response == nil
    end
  end
end
