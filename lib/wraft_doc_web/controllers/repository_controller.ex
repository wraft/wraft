defmodule WraftDocWeb.Api.V1.RepositoryController do
  use WraftDocWeb, :controller

  alias WraftDoc.Storage
  alias WraftDoc.Storage.Repository

  action_fallback(WraftDocWeb.FallbackController)

  def index(conn, _params) do
    repositories = Storage.list_repositories()
    render(conn, :index, repositories: repositories)
  end

  def create(conn, %{"repository" => repository_params}) do
    with {:ok, %Repository{} = repository} <- Storage.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository}")
      |> render(:show, repository: repository)
    end
  end

  def show(conn, %{"id" => id}) do
    repository = Storage.get_repository!(id)
    render(conn, :show, repository: repository)
  end

  def update(conn, %{"id" => id, "repository" => repository_params}) do
    repository = Storage.get_repository!(id)

    with {:ok, %Repository{} = repository} <-
           Storage.update_repository(repository, repository_params) do
      render(conn, :show, repository: repository)
    end
  end

  def delete(conn, %{"id" => id}) do
    repository = Storage.get_repository!(id)

    with {:ok, %Repository{}} <- Storage.delete_repository(repository) do
      send_resp(conn, :no_content, "")
    end
  end
end
