defmodule WraftDoc.Document.Pipeline.HookTriggerHistoryTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.HookTriggerHistory
  import WraftDoc.Factory

  @valid_attrs %{
    meta: %{name: "John Doe", post: "Developer"}
  }

  test "changeset with valid attrs" do
    changeset = HookTriggerHistory.changeset(%HookTriggerHistory{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = HookTriggerHistory.changeset(%HookTriggerHistory{}, %{})
    refute changeset.valid?
  end
end
