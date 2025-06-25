defmodule WraftDocWeb.Api.V1.ModelController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Models
  alias WraftDoc.Models.Model

  def swagger_definitions do
    %{
      Model:
        swagger_schema do
          title("AI Model")
          description("An AI model configuration")

          properties do
            id(:string, "Model ID", required: true)
            name(:string, "Name of the model", required: true)
            description(:string, "Description of the model", required: true)
            provider(:string, "AI provider (e.g., OpenAI, Anthropic)", required: true)
            endpoint_url(:string, "API endpoint URL", required: true)
            is_local(:boolean, "Whether the model is hosted locally", required: true)

            is_thinking_model(:boolean, "Whether this is a thinking/reasoning model",
              required: true
            )

            daily_request_limit(:integer, "Daily request limit", required: true)
            daily_token_limit(:integer, "Daily token limit", required: true)
            status(:string, "Status of the model", required: true)
            model_name(:string, "Technical model name", required: true)
            model_type(:string, "Type of model", required: true)
            model_version(:string, "Version of the model", required: true)
            creator_id(:string, "Creator user ID")
            organisation_id(:string, "Organisation ID")
            inserted_at(:string, "When was the model created", format: "ISO-8601")
            updated_at(:string, "When was the model last updated", format: "ISO-8601")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "GPT-4 Model",
            description: "OpenAI GPT-4 model for text generation",
            provider: "OpenAI",
            endpoint_url: "https://api.openai.com/v1/chat/completions",
            is_local: false,
            is_thinking_model: false,
            daily_request_limit: 1000,
            daily_token_limit: 100_000,
            status: "active",
            model_name: "gpt-4",
            model_type: "chat",
            model_version: "0613",
            creator_id: "user-456",
            organisation_id: "org-789",
            inserted_at: "2023-01-01T12:00:00Z",
            updated_at: "2023-01-01T12:00:00Z"
          })
        end,
      ModelRequest:
        swagger_schema do
          title("Model Request")
          description("Request body for creating or updating a model")
          type(:object)

          required([
            :name,
            :description,
            :provider,
            :endpoint_url,
            :is_local,
            :is_thinking_model,
            :daily_request_limit,
            :daily_token_limit,
            :auth_key,
            :status,
            :model_name,
            :model_type,
            :model_version
          ])

          properties do
            name(:string, "Name of the model", required: true)
            description(:string, "Description of the model", required: true)
            provider(:string, "AI provider (e.g., OpenAI, Anthropic)", required: true)
            endpoint_url(:string, "API endpoint URL", required: true)
            is_default(:boolean, "Whether this is the default model")
            is_local(:boolean, "Whether the model is hosted locally", required: true)

            is_thinking_model(:boolean, "Whether this is a thinking/reasoning model",
              required: true
            )

            daily_request_limit(:integer, "Daily request limit", required: true)
            daily_token_limit(:integer, "Daily token limit", required: true)
            auth_key(:string, "Authentication key for the model", required: true)
            status(:string, "Status of the model", required: true)
            model_name(:string, "Technical model name", required: true)
            model_type(:string, "Type of model", required: true)
            model_version(:string, "Version of the model", required: true)
          end

          example(%{
            name: "GPT-4 Model",
            description: "OpenAI GPT-4 model for text generation",
            provider: "OpenAI",
            endpoint_url: "https://api.openai.com/v1/chat/completions",
            is_local: false,
            is_thinking_model: false,
            daily_request_limit: 1000,
            daily_token_limit: 100_000,
            auth_key: "sk-...",
            status: "active",
            model_name: "gpt-4",
            model_type: "chat",
            model_version: "0613"
          })
        end,
      Models:
        swagger_schema do
          title("Models List")
          description("List of AI models")
          type(:array)
          items(Schema.ref(:Model))
        end
    }
  end

  @doc """
  List all AI models.
  """
  swagger_path :index do
    get("/ai/models")
    summary("List all AI models")
    description("Retrieve a list of all AI models")

    response(200, "Ok", Schema.ref(:Models))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params),
    do:
      render(conn, :index,
        models: Models.list_ai_models(conn.assigns.current_user.current_org_id)
      )

  @doc """
  Create a new AI model.
  """
  swagger_path :create do
    post("/ai/models")
    summary("Create a new AI model")
    description("Create a new AI model configuration")

    parameters do
      model(:body, Schema.ref(:ModelRequest), "Model to be created", required: true)
    end

    response(201, "Created", Schema.ref(:Model))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

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

  @doc """
  Show a specific AI model.
  """
  swagger_path :show do
    get("/ai/models/{id}")
    summary("Show an AI model")
    description("Retrieve details of a specific AI model")

    parameters do
      id(:path, :string, "Model ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Model))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Model{} = model <- Models.get_model(id, current_user.current_org_id) do
      render(conn, :show, model: model)
    end
  end

  @doc """
  Update an existing AI model.
  """
  swagger_path :update do
    put("/ai/models/{id}")
    summary("Update an AI model")
    description("Update an existing AI model configuration")

    parameters do
      id(:path, :string, "Model ID", required: true)
      model(:body, Schema.ref(:ModelRequest), "Model data to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Model))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

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

  @doc """
  Delete an AI model.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/ai/models/{id}")
    summary("Delete an AI model")
    description("Delete an existing AI model configuration")

    parameters do
      id(:path, :string, "Model ID", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Model{} = model <- Models.get_model(id, current_user.current_org_id),
         {:ok, %Model{}} <- Models.delete_model(model) do
      send_resp(conn, :no_content, "")
    end
  end
end
