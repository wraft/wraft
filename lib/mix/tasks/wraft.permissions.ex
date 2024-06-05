defmodule Mix.Tasks.Wraft.Permissions do
  @moduledoc """
      Read the permissions from the 'permissions.csv' file and insert them into the 'permissions' table.
      If any new permissions exist in the 'permissions.csv' file, they will be added to the 'permissions' table.
      If an existing permission is attempted to be inserted into the 'permissions' table, it will be ignored and the program will continue.

      $ mix wraft.permissions
  """

  @shortdoc "Updates Permissions"

  use Mix.Task
  require Logger

  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  @requirements ["app.start"]
  @mix_env Mix.env()
  @permissions_file Application.compile_env!(:wraft_doc, [:permissions_file])

  def run([]) do
    if @mix_env == :prod do
      :wraft_doc |> :code.priv_dir() |> Path.join(@permissions_file) |> run()
    else
      run(@permissions_file)
    end
  end

  def run(permissions_file) do
    Logger.info("Updating Permissions started.")

    permissions_file
    |> File.stream!()
    |> CSV.decode(headers: ["name", "resource", "action"])
    |> Enum.each(fn {:ok, permission} -> insert_permission(permission) end)

    Logger.info("Updating Permissions end.")
  end

  defp insert_permission(permission) do
    %Permission{}
    |> Permission.changeset(permission)
    |> Repo.insert()
  end
end
