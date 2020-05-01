defmodule WraftDoc.Enterprise.Flow.StateTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Enterprise.Flow.State

  @valid_attrs %{
    state: "published",
    order: 1,
    organisation_id: 12
  }
  @invalid_attrs %{state: "published"}

  test "changeset with valid attrs" do
    changeset = State.changeset(%State{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = State.changeset(%State{}, @invalid_attrs)
    refute changeset.valid?
  end
end
