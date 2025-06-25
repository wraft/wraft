defmodule WraftDocWeb.Api.V1.PromptsController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Models
  alias WraftDoc.Models.Prompt

  def swagger_definitions do
    %{
      Prompt:
        swagger_schema do
          title("Prompt")
          description("An AI prompt")

          properties do
            id(:string, "Prompt ID", required: true)
            title(:string, "Title of the prompt", required: true)
            prompt(:string, "The prompt text", required: true)
            status(:string, "Status of the prompt", required: true)
            type(:string, "Type of prompt (extraction, suggestion, refinement)", required: true)
            model_id(:string, "Associated AI model ID")
            creator_id(:string, "Creator user ID")
            organisation_id(:string, "Organisation ID")
            inserted_at(:string, "When was the prompt created", format: "ISO-8601")
            updated_at(:string, "When was the prompt last updated", format: "ISO-8601")
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            title: "Extract Invoice Data",
            prompt: "Extract the invoice number, date, and total amount from this document.",
            status: "active",
            type: "extraction",
            model_id: "model-123",
            creator_id: "user-456",
            organisation_id: "org-789",
            inserted_at: "2023-01-01T12:00:00Z",
            updated_at: "2023-01-01T12:00:00Z"
          })
        end,
      PromptRequest:
        swagger_schema do
          title("Prompt Request")
          description("Request body for creating or updating a prompt")
          type(:object)
          required([:title, :prompt, :status, :type])

          properties do
            title(:string, "Title of the prompt", required: true)
            prompt(:string, "The prompt text", required: true)
            status(:string, "Status of the prompt", required: true)
            type(:string, "Type of prompt (extraction, suggestion, refinement)", required: true)
          end

          example(%{
            title: "Enhancement",
            prompt: "Enhance the document with additional information",
            status: "active",
            type: "extraction"
          })
        end,
      Prompts:
        swagger_schema do
          title("Prompts List")
          description("List of prompts")
          type(:array)
          items(Schema.ref(:Prompt))
        end
    }
  end

  @doc """
  List all prompts.
  """
  swagger_path :index do
    get("/ai/prompts")
    summary("List all prompts")
    description("Retrieve a list of all AI prompts")

    response(200, "Ok", Schema.ref(:Prompts))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns[:current_user]
    prompts = Models.list_prompts(current_user.current_org_id)
    render(conn, :index, prompts: prompts)
  end

  @doc """
  Create a new prompt.
  """
  swagger_path :create do
    post("/ai/prompts")
    summary("Create a new prompt")
    description("Create a new AI prompt")

    parameters do
      prompt(:body, Schema.ref(:PromptRequest), "Prompt to be created", required: true)
    end

    response(201, "Created", Schema.ref(:Prompt))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Prompt{id: id} = prompt} <-
           Models.create_prompt(
             Map.merge(params, %{
               "creator_id" => current_user.id,
               "organisation_id" => current_user.current_org_id
             })
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/prompts/#{id}")
      |> render(:show, prompt: prompt)
    end
  end

  @doc """
  Show a specific prompt.
  """
  swagger_path :show do
    get("/ai/prompts/{id}")
    summary("Show a prompt")
    description("Retrieve details of a specific prompt")

    parameters do
      id(:path, :string, "Prompt ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Prompt))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with %Prompt{} = prompt <- Models.get_prompt(id) do
      render(conn, :show, prompt: prompt)
    end
  end

  @doc """
  Update an existing prompt.
  """
  swagger_path :update do
    put("/ai/prompts/{id}")
    summary("Update a prompt")
    description("Update an existing AI prompt")

    parameters do
      id(:path, :string, "Prompt ID", required: true)
      prompts(:body, Schema.ref(:PromptRequest), "Prompt data to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Prompt))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Prompt{} = prompt <- Models.get_prompt(id),
         {:ok, %Prompt{} = prompt} <-
           Models.update_prompt(
             prompt,
             Map.merge(params, %{
               "creator_id" => current_user.id,
               "organisation_id" => current_user.current_org_id
             })
           ) do
      render(conn, :show, prompt: prompt)
    end
  end

  @doc """
  Delete a prompt.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/ai/prompts/{id}")
    summary("Delete a prompt")
    description("Delete an existing AI prompt")

    parameters do
      id(:path, :string, "Prompt ID", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %Prompt{} = prompt <- Models.get_prompt(id),
         {:ok, %Prompt{}} <- Models.delete_prompt(prompt) do
      send_resp(conn, :no_content, "")
    end
  end
end
