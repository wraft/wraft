defmodule WraftDocWeb.Api.V1.WorkflowCredentialController do
  @moduledoc """
  Controller for managing workflow credentials.
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.Authorized, roles: [:creator], create_new: true
  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Workflows.WorkflowCredentials

  def swagger_definitions do
    %{
      WorkflowCredential:
        swagger_schema do
          title("Workflow Credential")
          description("Encrypted credentials for workflow adaptors")

          properties do
            id(:string, "The ID of the credential", required: true)
            name(:string, "Credential name", required: true)
            adaptor_type(:string, "Adaptor type (http, slack, etc.)", required: true)
            metadata(:object, "Non-sensitive metadata")
          end
        end
    }
  end

  swagger_path :index do
    get("/workflow_credentials")
    summary("List workflow credentials")
    description("Returns all credentials for the current organization")

    response(200, "Success")
    response(401, "Unauthorized")
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    credentials = WorkflowCredentials.list_credentials(current_user)
    render(conn, "index.json", credentials: credentials)
  end

  swagger_path :show do
    get("/workflow_credentials/{id}")
    summary("Get credential details")
    description("Returns a credential with decrypted credentials (masked in response)")

    parameters do
      id(:path, :string, "Credential ID", required: true)
    end

    response(200, "Success")
    response(404, "Not found")
    response(401, "Unauthorized")
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case WorkflowCredentials.get_credential(current_user, id) do
      nil -> {:error, :not_found}
      credential -> render(conn, "show.json", credential: credential)
    end
  end

  swagger_path :create do
    post("/workflow_credentials")
    summary("Create a new credential")
    description("Creates and encrypts credentials for workflow adaptors")

    parameters do
      body(:body, Schema.ref(:CreateCredentialRequest), "Credential data", required: true)
    end

    response(201, "Created")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
  end

  def create(conn, %{"name" => _, "adaptor_type" => _, "credentials" => _} = params) do
    current_user = conn.assigns.current_user

    case WorkflowCredentials.create_credential(current_user, params) do
      {:ok, credential} ->
        conn
        |> put_status(:created)
        |> render("show.json", credential: credential)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(WraftDocWeb.ErrorView)
        |> render("error.json", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    case WorkflowCredentials.get_credential(current_user, id) do
      nil ->
        {:error, :not_found}

      credential ->
        case WorkflowCredentials.update_credential(current_user, credential, params) do
          {:ok, updated_credential} ->
            render(conn, "show.json", credential: updated_credential)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(WraftDocWeb.ErrorView)
            |> render("error.json", changeset: changeset)
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case WorkflowCredentials.get_credential(current_user, id) do
      nil ->
        {:error, :not_found}

      credential ->
        case WorkflowCredentials.delete_credential(current_user, credential) do
          {:ok, _credential} ->
            send_resp(conn, :no_content, "")

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(WraftDocWeb.ErrorView)
            |> render("error.json", changeset: changeset)
        end
    end
  end
end
