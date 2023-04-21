defmodule WraftDoc.Authorization do
  @moduledoc """
  Module that handles the repo connections of the authorization context.
  """
  import Ecto.Query

  alias WraftDoc.Authorization.Permission
  alias WraftDoc.Repo

  @doc """
  Lists all permissions and group them by resource.
  """
  def list_permissions do
    Permission
    |> Repo.all()
    |> Enum.group_by(& &1.resource)
  end

  def create_permission(params \\ %{}) do
    %Permission{}
    |> Permission.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Get a permission from its UUID.
  """
  @spec get_permission(Ecto.UUID.t()) :: Permission.t() | nil
  def get_permission(id), do: Repo.get_by(Permission, id: id)

  @doc """
  Deletes a resource.
  """
  @spec delete_permission(Permission.t()) :: {:ok, Permission.t()} | {:error, Ecto.Changeset.t()}
  def delete_permission(permission), do: Repo.delete(permission)

  @doc """
  Lists all resources we have in Wraft.
  """
  @spec list_resources() :: list()
  def list_resources do
    Permission
    |> distinct(true)
    |> select([p], p.resource)
    |> Repo.all()
  end
end
