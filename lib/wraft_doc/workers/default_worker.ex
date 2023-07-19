defmodule WraftDoc.Workers.DefaultWorker do
  @moduledoc """
  Default Oban worker for all trivial jobs.
  """
  use Oban.Worker, queue: :default

  require Logger

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Repo

  @superadmin_role "superadmin"
  @editor_role "editor"

  @impl Oban.Worker
  def perform(%Job{
        args: %{"organisation_id" => organisation_id, "user_id" => user_id},
        tags: ["personal_organisation_roles"]
      }) do
    Multi.new()
    |> Multi.insert(:role, %Role{name: @superadmin_role, organisation_id: organisation_id})
    |> Multi.insert(:user_role, fn %{role: role} ->
      %UserRole{role_id: role.id, user_id: user_id}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Personal Organisation role insert failed", changeset: changeset)
        {:error, changeset}
    end
  end

  def perform(%Job{
        args: %{"organisation_id" => organisation_id, "user_id" => user_id},
        tags: ["organisation_roles"]
      }) do
    permissions = get_editor_permissions()

    Multi.new()
    |> Multi.insert(:superadmin_role, %Role{
      name: @superadmin_role,
      organisation_id: organisation_id
    })
    |> Multi.insert(:editor_role, %Role{
      name: @editor_role,
      organisation_id: organisation_id,
      permissions: permissions
    })
    |> Multi.run(:assign_role, fn _, %{superadmin_role: role} ->
      Account.create_user_role(user_id, role.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        :ok

      {:error, _, changeset, _} ->
        Logger.error("Organisation role insert failed", changeset: changeset)
        {:error, changeset}
    end
  end

  def perform(%Job{args: %{"user_id" => user_id, "role_id" => role_id}, tags: ["assign_role"]}) do
    Account.create_user_role(user_id, role_id)
  end

  # Private

  defp get_editor_permissions do
    "priv/repo/data/rbac/editor_permissions.csv"
    |> File.stream!()
    |> CSV.decode()
    |> Enum.map(fn {:ok, [permission]} -> permission end)
  end
end
