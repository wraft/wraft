defmodule WraftDoc.Repo.Migrations.UpdatedPermissions do
  @moduledoc """
  Script for repopulating permissions from CSV and updating all roles with these permissions.

  Run with:
      mix run priv/repo/data/migrations/repopulate_permissions_and_update_roles.exs
  """

  require Logger
  alias Ecto.Adapters.SQL, as: SQL
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
    Logger.info(":repeat: Updating roles with specific permissions")

    editor_permissions_file =
      Path.join(:code.priv_dir(:wraft_doc), "repo/data/rbac/editor_permissions.csv")

    editor_permissions =
      editor_permissions_file
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    if editor_permissions == [] do
      Logger.warn(":warning: No editor permissions found in file: #{editor_permissions_file}")
    else
      sql = "UPDATE role SET permissions = $1 WHERE name = 'editor'"
      SQL.query!(Repo, sql, [editor_permissions])
      Logger.info(":pencil: Set specific editor permissions from CSV")
    end

    sql_superadmin = "UPDATE role SET permissions = '{}' WHERE name = 'superadmin'"
    SQL.query!(Repo, sql_superadmin)

    sql_others = "UPDATE role SET permissions = '{}' WHERE name NOT IN ('superadmin', 'editor')"
    SQL.query!(Repo, sql_others)

    Logger.info(":no_entry_sign: Cleared permissions for all roles except superadmin and editor")
  end
end

WraftDoc.Repo.Migrations.UpdatedPermissions.run()
