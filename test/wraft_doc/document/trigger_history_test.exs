defmodule WraftDoc.Document.Pipeline.TriggerHistoryTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.TriggerHistory

  # import WraftDoc.Factory

  @valid_attrs %{
    meta: %{name: "John Doe", post: "Developer"},
    state: 1
  }

  test "changeset with valid attrs" do
    params = @valid_attrs |> Map.put(:creator_id, 1)
    changeset = TriggerHistory.changeset(%TriggerHistory{}, params)
    assert changeset.valid?
  end

  test "changeset with invalid attrs" do
    changeset = TriggerHistory.changeset(%TriggerHistory{}, %{})
    refute changeset.valid?
  end

  test "hook changeset with valid attrs" do
    changeset = TriggerHistory.hook_changeset(%TriggerHistory{}, @valid_attrs)
    IO.inspect(changeset)
    assert changeset.valid?
  end

  test "hook changeset with invalid attrs" do
    changeset = TriggerHistory.hook_changeset(%TriggerHistory{}, %{})
    refute changeset.valid?
  end
end
