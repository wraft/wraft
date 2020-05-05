defmodule WraftDoc.DocumentTest do
  import Ecto.Query
  import Ecto
  import WraftDoc.Factory
  use WraftDoc.ModelCase
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
  @invalid_layout_attrs %{}

  test "create layout on valid attributes" do
    user = insert(:user)
    engine = insert(:engine)
    count_before = Layout |> Repo.all() |> length()
    layout = Document.create_layout(user, engine, @valid_layout_attrs)
    count_after = Layout |> Repo.all() |> length()
    count_before + 1 == count_after
    assert layout.name == @valid_layout_attrs["name"]
    assert layout.description == @valid_layout_attrs["description"]
    assert layout.width == @valid_layout_attrs["width"]
    assert layout.height == @valid_layout_attrs["height"]
    assert layout.unit == @valid_layout_attrs["unit"]
    assert layout.slug == @valid_layout_attrs["slug"]
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
end
