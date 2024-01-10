defmodule WraftDoc.Enterprise.FlowTest do
  use WraftDoc.ModelCase
  @moduletag :enterprise
  alias WraftDoc.Enterprise.Flow
  import WraftDoc.Factory
  @valid_attrs %{name: "flow name", controlled: true}
  @invalid_attrs %{}
  test "changeset with valid attrs" do
    organisation = insert(:organisation)
    valid_attrs = Map.put(@valid_attrs, :organisation_id, organisation.id)
    changeset = Flow.changeset(%Flow{}, valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = Flow.changeset(%Flow{}, @invalid_attrs)
    refute changeset.valid?
  end

  # TODO include tests for unique constraint in changeset/2
  # TODO include tests for controlled_changeset -> valid , invalid , constraints
  # TODO include tests for update_changeset -> valid , invalid , constraints
  # TODO include tests for update_controlled_changeset -> valid , invalid , constraints
  # TODO include tests for align_order_changeset -> valid , invalid
end
