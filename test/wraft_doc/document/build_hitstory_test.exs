defmodule WraftDoc.Document.Instance.HistoryTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Document.Instance.History
  @moduletag :document
  {:ok, start_time} = NaiveDateTime.new(2020, 03, 17, 20, 20, 20)
  {:ok, end_time} = NaiveDateTime.new(2020, 03, 17, 20, 21, 20)

  @valid_attrs %{
    status: "current_status",
    exit_code: 0,
    start_time: start_time,
    end_time: end_time,
    delay: 60_000
  }
  @invalid_attrs %{status: "current_status"}
  test " changeset with valid attributes" do
    changeset = History.changeset(%History{}, @valid_attrs)

    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = History.changeset(%History{}, @invalid_attrs)
    refute changeset.valid?
  end
end
