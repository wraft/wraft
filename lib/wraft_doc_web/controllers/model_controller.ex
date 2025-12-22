defmodule WraftDocWeb.Api.V1.ModelController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Models
  alias WraftDoc.Models.Model
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Model, as: ModelSchema

  tags(["AI"])

  operation(:index,
    summary: "List all AI models",
    description: "Retrieve a list of all AI models",
    responses: [
      ok: {"Ok", "application/json", ModelSchema.Models},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params),
    do:
      render(conn, :index,
        models: Models.list_ai_models(conn.assigns.current_user.current_org_id)
      )

  operation(:create,
    summary: "Create a new AI model",
    description: "Create a new AI model configuration",
    request_body: {"Model to be created", "application/json", ModelSchema.ModelRequest},
    responses: [
      created: {"Created", "application/json", ModelSchema.Model},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    params =
      Map.merge(params, %{
        "creator_id" => current_user.id,
        "organisation_id" => current_user.current_org_id
      })

    with {:ok, %Model{id: model_id} = model} <- Models.create_model(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/ai_models/#{model_id}")
      |> render(:show, model: model)
    end
  end

  operation(:show,
    summary: "Show an AI model",
    description: "Retrieve details of a specific AI model",
    parameters: [
      id: [in: :path, type: :string, description: "Model ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ModelSchema.Model},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Model{} = model <- Models.get_model(id, current_user.current_org_id) do
      render(conn, :show, model: model)
    end
  end

  operation(:update,
    summary: "Update an AI model",
    description: "Update an existing AI model configuration",
    parameters: [
      id: [in: :path, type: :string, description: "Model ID", required: true]
    ],
    request_body: {"Model data to be updated", "application/json", ModelSchema.ModelRequest},
    responses: [
      ok: {"Ok", "application/json", ModelSchema.Model},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    params =
      Map.merge(params, %{
        "creator_id" => current_user.id,
        "organisation_id" => current_user.current_org_id
      })

    with %Model{} = model <- Models.get_model(id, current_user.current_org_id),
         {:ok, %Model{} = model} <- Models.update_model(model, params) do
      render(conn, :show, model: model)
    end
  end

  operation(:delete,
    summary: "Delete an AI model",
    description: "Delete an existing AI model configuration",
    parameters: [
      id: [in: :path, type: :string, description: "Model ID", required: true]
    ],
    responses: [
      no_content: {"No Content", "application/json", nil},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Model{} = model <- Models.get_model(id, current_user.current_org_id),
         {:ok, %Model{}} <- Models.delete_model(model) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:set_default,
    summary: "Set an AI model as default",
    description: "Set an existing AI model as default",
    parameters: [
      id: [in: :path, type: :string, description: "Model ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ModelSchema.Model},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec set_default(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def set_default(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Model{} = model <- Models.get_model(id, current_user.current_org_id),
         {:ok, %Model{} = model} <- Models.set_as_default_model(model) do
      render(conn, :show, model: model)
    end
  end
end
