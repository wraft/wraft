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
  def list_permissions(params \\ %{}) do
    Permission
    |> where(^permission_filter_by_name(params))
    |> where(^permission_filter_by_resource(params))
    |> Repo.all()
    |> Enum.group_by(& &1.resource)
  end

  defp permission_filter_by_name(%{"name" => name} = _params),
    do: dynamic([p], ilike(p.name, ^"%#{name}%"))

  defp permission_filter_by_name(_), do: true

  defp permission_filter_by_resource(%{"resource" => resource} = _params),
    do: dynamic([p], ilike(p.resource, ^"%#{resource}%"))

  defp permission_filter_by_resource(_), do: true

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
