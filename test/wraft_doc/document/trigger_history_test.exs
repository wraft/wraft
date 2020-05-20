defmodule WraftDoc.Document.Pipeline.TriggerHistoryTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.TriggerHistory

  # import WraftDoc.Factory

  @valid_attrs %{
    data: %{name: "John Doe", post: "Developer"},
    state: 1
  }

  @valid_update_attrs %{
    meta: %{error: :pipeline_not_exist},
    state: 1
  }

  describe "changeset/2" do
    test "changeset with valid attrs" do
      params = @valid_attrs |> Map.put(:creator_id, 1)
      changeset = TriggerHistory.changeset(%TriggerHistory{}, params)
      assert changeset.valid?
    end

    test "changeset with invalid attrs" do
      changeset = TriggerHistory.changeset(%TriggerHistory{}, %{})
      refute changeset.valid?
    end
  end

  describe "hook_changeset/2" do
    test "hook changeset with valid attrs" do
      changeset = TriggerHistory.hook_changeset(%TriggerHistory{}, @valid_attrs)
      assert changeset.valid?
    end

    test "hook changeset with invalid attrs" do
      changeset = TriggerHistory.hook_changeset(%TriggerHistory{}, %{})
      refute changeset.valid?
    end
  end

  describe "update_changeset/2" do
    test "update changeset with valid update attrs" do
      changeset = TriggerHistory.update_changeset(%TriggerHistory{}, @valid_update_attrs)
      assert changeset.valid?
    end

    test "update changeset with invalid attrs" do
      changeset = TriggerHistory.update_changeset(%TriggerHistory{}, %{})
      refute changeset.valid?
    end
  end
end
