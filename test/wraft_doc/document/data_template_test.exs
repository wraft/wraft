defmodule WraftDoc.Document.DataTemplateTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.DataTemplate

  @valid_attrs %{
    title: "industry",
    title_template: "test",
    data: "administrative",
    serialized: %{title: "test", body: "test"}
  }
  @invalid_attrs %{}
  test "changeset with valid attributes" do
    changeset = DataTemplate.changeset(%DataTemplate{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = DataTemplate.changeset(%DataTemplate{}, @invalid_attrs)
    refute changeset.valid?
  end
end
