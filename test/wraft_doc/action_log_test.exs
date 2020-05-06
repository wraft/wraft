defmodule WraftDoc.ActionLogTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.ActionLog

  @valid_attrs %{
    actor: %{
      name: "John Doe",
      email: "johndoe@gmail.com"
    },
    remote_ip: "192.168.1.1",
    actor_agent: "Macintosh Safari",
    request_path: "api/v1/test",
    request_method: "GET",
    action: "create",
    params: %{data: "test data", file: %{path: "/test", filename: "tst.txt"}}
  }
  @invalid_attrs %{}

  test "authorized action changeset with valid data" do
    user = insert(:user)
    params = Map.put(@valid_attrs, :user_id, user.id)
    changeset = ActionLog.authorized_action_changeset(%ActionLog{}, params)
    assert changeset.valid?
  end

  test "unauthorized action changeset with valid data" do
    changeset = ActionLog.unauthorized_action_changeset(%ActionLog{}, @valid_attrs)
    assert changeset.valid?
  end

  test "authorized changeset with invalid attributes" do
    changeset = ActionLog.authorized_action_changeset(%ActionLog{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "unauthorized changeset with invalid attributes" do
    changeset = ActionLog.unauthorized_action_changeset(%ActionLog{}, @invalid_attrs)
    refute changeset.valid?
  end
end
