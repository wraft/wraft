defmodule WraftDocWeb.Api.V1.RepositoryController do
  @moduledoc """
  API endpoints for managing document repositories.

  Repositories are isolated storage containers that organize documents and folders
  for users and organizations. Each repository has configurable storage limits
  and access controls.

  ## Repository Lifecycle
  - Created via `/api/repositories` POST
  - Managed via CRUD operations
  - Automatically setup for new users via `/api/repository/setup`
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Storages
  alias WraftDoc.Storages.Repository
  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Repositories"])

  operation(:index,
    summary: "List repositories",
    description: """
    Returns a paginated list of repositories accessible to the current user.

    ### Filtering
    - Filter by status: `?status=active`
    - Filter by organization: `?organization_id=UUID`

    ### Sorting
    - Sort by name: `?sort=name`
    - Sort by storage used: `?sort=storage_used`
    """,
    responses: [
      ok: {"OK", "application/json", Schemas.Repository.RepositoriesList},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def index(conn, _params) do
    repositories = Storages.list_repositories()
    render(conn, "index.json", repositories: repositories)
  end

  operation(:create,
    summary: "Create a repository",
    description: "Creates a new storage repository",
    request_body:
      {"Repository creation parameters", "application/json",
       Schemas.Repository.RepositoryCreateParams},
    responses: [
      created: {"Created", "application/json", Schemas.Repository.Repository},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  def create(conn, %{"repository" => repository_params}) do
    with {:ok, %Repository{} = repository} <- Storages.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  operation(:show,
    summary: "Get repository details",
    description: "Returns detailed information about a specific repository",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the repository to fetch", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", Schemas.Repository.Repository},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    repository = Storages.get_repository!(id)
    render(conn, :show, repository: repository)
  end

  operation(:check_setup,
    summary: "Check repository setup status",
    description: """
    Checks if the current user has any repositories in their organization.

    ### Typical Responses:
    - 200 with empty array: No repositories exist (user needs to setup)
    - 200 with repositories: User has existing repositories

    Used during user onboarding to determine if default repository creation is needed.
    """,
    responses: [
      ok: {"OK", "application/json", Schemas.Repository.RepositoriesList},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  def check_setup(conn, _params) do
    user_id = conn.assigns.current_user.id
    organisation_id = conn.assigns.current_user.current_org_id

    repositories = Storages.list_repositories_by_user_and_organisation(user_id, organisation_id)

    render(conn, :index, repositories: repositories)
  end

  operation(:setup_repository,
    summary: "Setup default repository",
    description: """
    Creates a default repository for the current user in their current organization.
    The repository will have a randomly generated name and default storage limits.
    """,
    responses: [
      created: {"Created", "application/json", Schemas.Repository.Repository},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

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

    with {:ok, %Repository{} = repository} <- Storages.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  operation(:update,
    summary: "Update repository",
    description: "Updates an existing repository",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the repository to update",
        required: true
      ]
    ],
    request_body:
      {"Repository update parameters", "application/json",
       Schemas.Repository.RepositoryUpdateParams},
    responses: [
      ok: {"OK", "application/json", Schemas.Repository.Repository},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id, "repository" => repository_params}) do
    repository = Storages.get_repository!(id)

    with {:ok, %Repository{} = repository} <-
           Storages.update_repository(repository, repository_params) do
      render(conn, :show, repository: repository)
    end
  end

  operation(:delete,
    summary: "Delete repository",
    description: "Permanently deletes a repository",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the repository to delete",
        required: true
      ]
    ],
    responses: [
      no_content: {"No Content", "application/json", nil},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    repository = Storages.get_repository!(id)

    with {:ok, %Repository{}} <- Storages.delete_repository(repository) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:export,
    summary: "Export repository as ZIP",
    description:
      "Exports all files in the repository as a ZIP archive and returns it as a binary download",
    request_body:
      {"Optional file name", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{file_name: %OpenApiSpex.Schema{type: :string}}
       }},
    responses: [
      ok: {"ZIP file returned successfully", "application/zip", nil},
      forbidden: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Repository not found", "application/json", Schemas.Error}
    ]
  )

  def export(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{name: repository_name} = _repository <-
           Storages.get_latest_repository(current_user.current_org_id) do
      Storages.repository_export_worker(
        current_user,
        Map.get(params, "file_name", repository_name)
      )

      json(conn, %{
        message: "Repository export started. You will receive an email when it’s ready."
      })
    end
  end
end
