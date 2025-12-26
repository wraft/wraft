defmodule WraftDoc.Workers.DefaultWorkerTest do
  @moduledoc """
  Tests for Oban worker for default jobs.
  """
  use WraftDoc.DataCase, async: false

  # TODO - Add tests to check the oban job is executed to create roles for personal organisation
  # TODO - Add tests to check if role is created
  # TODO - Add tests to check if user_role is created
  # TODO - Add tests to check if error logs are created

  # TODO - Add tests to check the oban job is executed to create roles for organisation
  # TODO - Add tests to check if default roles {superadmin, editor} are created
  # TODO - Add tests to check if the superadmin role is assigned to the creator of the organisation
  # TODO - Add tests to capture the error log

  # TODO - Add tests to check if role is assigned to a user
end
