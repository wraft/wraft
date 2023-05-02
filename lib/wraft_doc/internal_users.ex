defmodule WraftDoc.InternalUsers do
  @moduledoc false

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo

  def change_internal_user, do: InternalUser.changeset(%InternalUser{})

  def get_by_email(email) do
    Repo.get_by(InternalUser, email: email)
  end
end
