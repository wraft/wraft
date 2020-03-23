defmodule WraftDoc.EngineTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Engine

  @valid_attrs %{
    name: "engine-1",
    api_route: "localhost:4000/api/route"
  }
  @invalid_attrs %{}

  test "changeset with valid attrs" do
    changeset = Engine.changeset(%Engine{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Engine.changeset(%Engine{}, @invalid_attrs)
    refute changeset.valid?
  end
end
