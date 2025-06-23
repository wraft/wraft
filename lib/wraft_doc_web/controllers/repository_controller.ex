defmodule WraftDocWeb.Api.V1.RepositoryController do
  use WraftDocWeb, :controller

  alias WraftDoc.Storage
  alias WraftDoc.Storage.Repository

  action_fallback(WraftDocWeb.FallbackController)

  def index(conn, _params) do
    repositories = Storage.list_repositories()
    render(conn, "index.json", repositories: repositories)
  end

  def create(conn, %{"repository" => repository_params}) do
    with {:ok, %Repository{} = repository} <- Storage.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  def show(conn, %{"id" => id}) do
    repository = Storage.get_repository!(id)
    render(conn, :show, repository: repository)
  end

  def check_setup(conn, _params) do
    user_id = conn.assigns.current_user.id
    organisation_id = conn.assigns.current_user.current_org_id

    repositories = Storage.list_repositories_by_user_and_organisation(user_id, organisation_id)

    render(conn, :index, repositories: repositories)
  end

  def setup_repository(conn, _params) do
    user_id = conn.assigns.current_user.id
    organisation_id = conn.assigns.current_user.current_org_id

    repo_name = "Repository_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"

    repository_params = %{
      "name" => repo_name,
      "description" => "Auto-generated repository for user setup",
      "storage_limit" => 10_000_000_000,
      "current_storage_used" => 0,
      "item_count" => 0,
      "status" => "active",
      "creator_id" => user_id,
      "organisation_id" => organisation_id
    }

    with {:ok, %Repository{} = repository} <- Storage.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
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
