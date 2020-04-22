defmodule WraftDoc.CounterTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.Counter

  @valid_attrs %{subject: "Subject:1", count: 1}
  @update_valid_attrs %{count: 1}

  @invalid_attrs %{subject: ""}
  @update_invalid_attrs %{count: ""}

  test "changeset with valid attributes" do
    changeset = Counter.changeset(%Counter{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Counter.changeset(%Counter{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "update changeset with valid attributes" do
    counter = insert(:counter)
    changeset = Counter.changeset(counter, @update_valid_attrs)
    assert changeset.valid?
  end

  test "update changeset with invalid attributes" do
    counter = insert(:counter)
    changeset = Counter.changeset(counter, @update_invalid_attrs)
    refute changeset.valid?
  end
end
