defmodule WraftDoc.Authorization do
  @moduledoc """
  Module that handles the repo connections of the authorization context.
  """
  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  def list_permissions, do: Repo.all(Permission)

  def create_permission(params \\ %{}) do
    %Permission{}
    |> Permission.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, permission} ->
        permission

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Get a permission from its UUID.
  """
  @spec get_permission(binary) :: Permission.t()
  def get_permission(id) do
    Repo.get_by(Permission, id: id)
  end

  @doc """
  Delete a resource.
  """
  @spec delete_permission(Permission.t()) :: {:ok, Permission.t()}
  def delete_permission(permission) do
    Repo.delete(permission)
  end
end
