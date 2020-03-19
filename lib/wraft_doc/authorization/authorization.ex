defmodule WraftDoc.Authorization do
  @moduledoc """
  Module that handles the repo connections of the authorization context.
  """
  import Ecto.Query
  import Ecto
  alias WraftDoc.{Repo, Authorization.Resource, Authorization.Permission, Account.Role}

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
    from(r in Resource,
      order_by: [asc: r.category]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Get a resource from its UUID.
  """
  @spec get_resource(binary) :: Resource.t()
  def get_resource(uuid) do
    Resource |> Repo.get_by(uuid: uuid)
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

  @doc """
  Create a permission.
  """
  @spec create_permission(Resource.t(), Role.t()) :: Permission.t() | {:error, Ecto.Changeset.t()}
  def create_permission(resource, role) do
    resource
    |> build_assoc(:permissions, role: role)
    |> Permission.changeset()
    |> Repo.insert()
    |> case do
      {:ok, permission} ->
        permission |> Repo.preload([:role, :resource])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Permission index.
  """
  @spec permission_index(map) :: map
  def permission_index(params) do
    from(r in Resource,
      order_by: [asc: r.category],
      preload: [{:permissions, :role}]
    )
    |> Repo.paginate(params)
  end
end
