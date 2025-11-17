defmodule Mix.Tasks.Wraft.PermissionsTest do
  @moduledoc """
  Test to ensure that permission table is updated using `mix update_permissions` command
  """
  use WraftDoc.DataCase, async: true
  import ExUnit.CaptureLog
  require Logger

  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  setup do
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: :warn) end)
  end

  describe "run/1" do
    test "new permission entry would be updated in permission table" do
      {:ok, log} =
        with_log(fn ->
          Mix.Tasks.Wraft.Permissions.run([])
        end)

      # Verify the specific permission was created
      assert %Permission{} = Repo.get_by(Permission, name: "test_permission:test")

      # Check for log content
      assert log =~ "Updating Permissions started."
      assert log =~ "Updating Permissions end."
    end
  end
end
