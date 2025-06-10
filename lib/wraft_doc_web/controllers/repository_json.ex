defmodule WraftDocWeb.RepositoryJSON do
  alias WraftDoc.Storage.Repository

  @doc """
  Renders a list of repositories.
  """
  def index(%{repositories: repositories}) do
    %{data: for(repository <- repositories, do: data(repository))}
  end

  @doc """
  Renders a single repository.
  """
  def show(%{repository: repository}) do
    %{data: data(repository)}
  end

  defp data(%Repository{} = repository) do
    %{
      id: repository.id,
      name: repository.name,
      description: repository.description,
      storage_limit: repository.storage_limit,
      current_storage_used: repository.current_storage_used,
      item_count: repository.item_count,
      status: repository.status
    }
  end
end
