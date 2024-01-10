defmodule WraftDoc.Document.Pipeline.TriggerHistoryTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.Pipeline.TriggerHistory
  @moduletag :document

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

  describe "get_state/1" do
    test "returns a state with valid input" do
      integer = TriggerHistory.states()[:executing]
      trigger = insert(:trigger_history, state: integer)
      string = TriggerHistory.get_state(trigger)
      assert string == "executing"
    end

    test "returns nil with invalid input" do
      response = TriggerHistory.get_state(%{state: 1})
      assert response == nil
    end
  end

  describe "changeset/2" do
    test "changeset with valid attrs" do
      user = insert(:user)
      params = Map.put(@valid_attrs, :creator_id, user.id)
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
