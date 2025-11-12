defmodule WraftDocWeb.Api.V1.RepositoryView do
  use WraftDocWeb, :view
  # alias WraftDoc.Storages.Repository

  def render("index.json", %{repositories: repositories}) do
    %{data: render_many(repositories, __MODULE__, "repository.json")}
  end

  def render("show.json", %{repository: repository}) do
    %{data: render_one(repository, __MODULE__, "repository.json")}
  end

  def render("repository.json", %{repository: repository}) do
    %{
      id: repository.id,
      name: repository.name,
      description: repository.description,
      status: repository.status,
      storage_limit: repository.storage_limit,
      current_storage_used: repository.current_storage_used,
      item_count: repository.item_count,
      creator_id: repository.creator_id,
      organisation_id: repository.organisation_id,
      inserted_at: repository.inserted_at,
      updated_at: repository.updated_at
    }
  end
end
