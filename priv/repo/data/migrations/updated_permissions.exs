defmodule WraftDoc.Repo.Migrations.UpdatedPermissions do
  @moduledoc """
  Script for repopulating permissions from CSV and updating all roles with these permissions.

  Run with:
      mix run priv/repo/data/migrations/repopulate_permissions_and_update_roles.exs
  """

  require Logger
  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  @permissions_file Path.join(:code.priv_dir(:wraft_doc), "repo/data/rbac/permissions.csv")

  def run do
    Logger.info("🔄 Starting permissions repopulation and role update")

    delete_existing_permissions()
    insert_permissions_from_csv()
    update_roles_with_all_permissions()

    Logger.info("✅ Permissions and roles updated successfully.")
  end

  defp delete_existing_permissions do
    {count, _} = Repo.delete_all(Permission)
    Logger.info("🧹 Deleted #{count} existing permissions")
  end

  defp insert_permissions_from_csv do
    permissions_list =
      @permissions_file
      |> File.stream!()
      |> CSV.decode(headers: ["name", "resource", "action"])
      |> Enum.map(fn {:ok, permission} ->
        %{
          name: permission["name"],
          resource: permission["resource"],
          action: permission["action"]
        }
      end)

    {count, _} = Repo.insert_all(Permission, permissions_list)
    Logger.info("✅ Inserted #{count} permissions from CSV")
  end

  defp update_roles_with_all_permissions do
    sql = """
    UPDATE role
    SET permissions = (
      SELECT ARRAY_AGG(name ORDER BY name)
      FROM permission
    );
    """

    Ecto.Adapters.SQL.query!(Repo, sql)
    Logger.info("🔁 Updated all roles to include all current permissions")
  end
end

WraftDoc.Repo.Migrations.UpdatedPermissions.run()
