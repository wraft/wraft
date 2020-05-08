defmodule WraftDoc.Enterprise.FlowTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Enterprise.Flow
  @valid_attrs %{name: "flow name", organisation_id: 12}
  @invalid_attrs %{}
  test "changeset with valid attrs" do
    changeset = Flow.changeset(%Flow{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Flow.changeset(%Flow{}, @invalid_attrs)
    refute changeset.valid?
  end
end
