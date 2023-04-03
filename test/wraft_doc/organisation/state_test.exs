defmodule WraftDoc.Enterprise.Flow.StateTest do
  use WraftDoc.ModelCase
  @moduletag :enterprise
  alias WraftDoc.Enterprise.Flow.State
  import WraftDoc.Factory

  @valid_attrs %{
    state: "published",
    order: 1
  }
  @invalid_attrs %{state: "published"}

  test "changeset with valid attrs" do
    flow = insert(:flow)
    organisation = insert(:organisation)
    valid_attrs = Map.merge(@valid_attrs, %{flow_id: flow.id, organisation_id: organisation.id})
    changeset = State.changeset(%State{}, valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = State.changeset(%State{}, @invalid_attrs)
    refute changeset.valid?
  end

  # TODO - tests for order_update_changeset
  # TOOD - tests for unique constraints in changeset/2
end
