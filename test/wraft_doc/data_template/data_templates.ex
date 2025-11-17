defmodule WraftDoc.DataTemplates.DataTemplatesTest do
  @moduledoc false
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  import Mox

  @moduletag :document

  alias WraftDoc.DataTemplates
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Repo
  setup :verify_on_exit!

  @valid_data_template_attrs %{
    "title" => "data_template title",
    "title_template" => "data_template title_template",
    "data" => "data_template data",
    "serialized" => %{
      "company" => "Apple"
    }
  }
  @invalid_data_template_attrs %{title: nil, title_template: nil, data: nil}

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

      {:ok, data_template} = DataTemplates.create_data_template(user, c_type, params)

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
      {:error, changeset} = DataTemplates.create_data_template(user, c_type, %{})

      assert %{
               title: ["can't be blank"],
               title_template: ["can't be blank"],
               data: ["can't be blank"]
             } ==
               errors_on(changeset)
    end
  end

  describe "data_template_index/2" do
    test "data_template index lists the data_template data" do
      user = insert(:user)
      content_type = insert(:content_type, creator: user)
      d1 = insert(:data_template, creator: user, content_type: content_type)
      d2 = insert(:data_template, creator: user, content_type: content_type)
      data_template_index = DataTemplates.data_template_index(content_type.id, %{page_number: 1})

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
        DataTemplates.data_template_index(content_type.id, %{"title" => "First", page_number: 1})

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
        DataTemplates.data_template_index(
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
        DataTemplates.data_templates_index_of_an_organisation(user, %{page_number: 1})

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
        DataTemplates.data_templates_index_of_an_organisation("anything else", "anything else")

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
        DataTemplates.data_templates_index_of_an_organisation(
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
        DataTemplates.data_templates_index_of_an_organisation(
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
      d_data_template = DataTemplates.get_data_template(user, data_template.id)
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
      d_data_template = DataTemplates.show_data_template(user, data_template.id)
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

      data_template =
        DataTemplates.update_data_template(data_template, @valid_data_template_attrs)

      assert data_template.title == @valid_data_template_attrs["title"]
      assert data_template.title_template == @valid_data_template_attrs["title_template"]
      assert data_template.data == @valid_data_template_attrs["data"]
      assert data_template.serialized == @valid_data_template_attrs["serialized"]
    end

    test "does not update data_template on invalid attrs" do
      data_template = insert(:data_template)

      {:error, changeset} =
        DataTemplates.update_data_template(data_template, @invalid_data_template_attrs)

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
      {:ok, _data_template} = DataTemplates.delete_data_template(data_template)

      refute Repo.get(DataTemplate, data_template.id)
    end
  end
end
