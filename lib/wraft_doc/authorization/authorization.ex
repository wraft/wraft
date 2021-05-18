defmodule WraftDoc.Authorization do
  @moduledoc """
  Module that handles the repo connections of the authorization context.
  """
  import Ecto.Query
  alias WraftDoc.{Authorization.Permission, Authorization.Resource, Repo}

  @doc """
  Create a resource.
  """
  @spec create_resource(map) :: {:ok, Resource.t()} | {:error, Ecto.Changeset.t()}
  def create_resource(params) do
    %Resource{} |> Resource.changeset(params) |> Repo.insert()
  end

  @doc """
  List all resources.
  """
  @spec resource_index(map) :: map
  def resource_index(params) do
    query = from(r in Resource, order_by: [asc: r.category])

    Repo.paginate(query, params)
  end

  @doc """
  Get a resource from its UUID.
  """
  @spec get_resource(binary) :: Resource.t()
  def get_resource(uuid) do
    Repo.get_by(Resource, uuid: uuid)
  end

  @doc """
  Update given resource.
  """
  @spec update_resource(Resource.t(), map) :: {:ok, Resource.t()} | {:error, Ecto.Changeset.t()}
  def update_resource(resource, params) do
    resource |> Resource.changeset(params) |> Repo.update()
  end

  @doc """
  Delete a resource.
  """
  @spec delete_resource(Resource.t()) :: {:ok, Resource.t()} | {:error, Ecto.Changeset.t()}
  def delete_resource(resource) do
    resource
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :permissions,
      message:
        "Cannot delete the resource. Some permissions depend on this resource. Update those resources and then try again.!"
    )
    |> Repo.delete()
  end

  def create_permission(params \\ %{}) do
    %Permission{}
    |> Permission.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, permission} ->
        Repo.preload(permission, [:role, :resource])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Permission index.
  """
  @spec permission_index(map) :: map
  def permission_index(params) do
    query = from(r in Resource, order_by: [asc: r.category], preload: [{:permissions, :role}])

    Repo.paginate(query, params)
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
