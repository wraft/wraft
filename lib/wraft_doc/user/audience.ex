defmodule WraftDoc.Account.User.Audience do
  @moduledoc """
  The action log model.
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.User

  schema "audience" do
    belongs_to(:user, User)
    belongs_to(:activity, WraftDoc.Account.Activity)
  end
end
