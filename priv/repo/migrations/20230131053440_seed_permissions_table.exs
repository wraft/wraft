defmodule WraftDoc.Repo.Migrations.SeedPermissionsTable do
  use Ecto.Migration
  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  def change do
    permissions_list =
      "priv/repo/data/rbac/permissions.csv"
      |> File.stream!()
      |> CSV.decode(headers: ["name", "resource", "action"])
      |> Enum.map(fn {:ok, permission} ->
        %{
          name: permission["name"],
          resource: permission["resource"],
          action: permission["action"]
        }
      end)

    Repo.insert_all(Permission, permissions_list)
  end
end
