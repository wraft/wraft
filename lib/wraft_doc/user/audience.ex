defmodule WraftDoc.User.Audience do
  @moduledoc """
  The action log model.
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.User

  schema "audience" do
    belongs_to(:user, User, type: Ecto.UUID)
    belongs_to(:activity, Spur.Activity, type: Ecto.UUID)
  end
end
