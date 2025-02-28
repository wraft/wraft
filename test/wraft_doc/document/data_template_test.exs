defmodule WraftDoc.Document.DataTemplateTest do
  use WraftDoc.ModelCase
  alias WraftDoc.DataTemplates.DataTemplate
  import WraftDoc.Factory
  @moduletag :document

  @valid_attrs %{
    title: "industry",
    title_template: "test",
    data: "administrative",
    serialized: %{title: "test", body: "test"}
  }
  @invalid_attrs %{}
  test "changeset with valid attributes" do
    ct = insert(:content_type)
    valid_attrs = Map.put(@valid_attrs, :content_type_id, ct.id)
    changeset = DataTemplate.changeset(%DataTemplate{}, valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = DataTemplate.changeset(%DataTemplate{}, @invalid_attrs)
    refute changeset.valid?
  end
end
