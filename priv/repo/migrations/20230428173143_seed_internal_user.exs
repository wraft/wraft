defmodule WraftDoc.Repo.Migrations.SeedInternalUser do
  use Ecto.Migration

  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo

  def up do
    email = System.get_env("WRAFT_ADMIN_EMAIL") || "admin@wraft.com"
    password = System.get_env("WRAFT_ADMIN_PASSWORD") || "wraftadmin"

    %InternalUser{}
    |> InternalUser.changeset(%{email: email, password: password})
    |> Repo.insert!()
  end

  def down do
    email = System.get_env("WRAFT_ADMIN_EMAIL") || "admin@wraft.com"
    InternalUser |> Repo.get_by!(email: email) |> Repo.delete!()
  end
end
