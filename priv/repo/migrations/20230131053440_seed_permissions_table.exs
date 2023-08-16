defmodule WraftDoc.Repo.Migrations.SeedPermissionsTable do
  use Ecto.Migration
  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  @file_path :wraft_doc |> :code.priv_dir() |> Path.join("repo/data/rbac/permissions.csv")

  def change do
    permissions_list =
      @file_path
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
