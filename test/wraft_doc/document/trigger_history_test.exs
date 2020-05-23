defmodule WraftDoc.Document.Pipeline.TriggerHistoryTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Pipeline.TriggerHistory

  # import WraftDoc.Factory

  @valid_attrs %{
    data: %{name: "John Doe", post: "Developer"},
    state: 1
  }

  @valid_update_attrs %{
    error: %{error: :pipeline_not_exist},
    state: 1,
    start_time: "2020-02-12T12:00:00"
  }

  @valid_trigger_end_attrs %{
    end_time: "2020-02-12T12:03:00"
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

  describe "trigger_end_changeset/2" do
    test "trigger end changeset with valid attrs" do
      changeset =
        TriggerHistory.trigger_end_changeset(%TriggerHistory{}, @valid_trigger_end_attrs)

      assert changeset.valid?
    end

    test "trigger end changeset with invalid attrs" do
      changeset = TriggerHistory.trigger_end_changeset(%TriggerHistory{}, %{})
      refute changeset.valid?
    end
  end

  test "states/0 returns a list" do
    states = TriggerHistory.states()

    assert states == [
             enqued: 1,
             executing: 2,
             pending: 3,
             partially_completed: 4,
             success: 5,
             failed: 6
           ]
  end
end
