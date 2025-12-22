defmodule WraftDocWeb.Api.V1.PromptsController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Models
  alias WraftDoc.Models.Prompt
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Prompt, as: PromptSchema

  tags(["AI"])

  operation(:index,
    summary: "List all prompts",
    description: "Retrieve a list of all AI prompts",
    responses: [
      ok: {"Ok", "application/json", PromptSchema.Prompts},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns[:current_user]
    prompts = Models.list_prompts(current_user.current_org_id)
    render(conn, :index, prompts: prompts)
  end

  operation(:create,
    summary: "Create a new prompt",
    description: "Create a new AI prompt",
    request_body: {"Prompt to be created", "application/json", PromptSchema.PromptRequest},
    responses: [
      created: {"Created", "application/json", PromptSchema.Prompt},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

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

  operation(:show,
    summary: "Show a prompt",
    description: "Retrieve details of a specific prompt",
    parameters: [
      id: [in: :path, type: :string, description: "Prompt ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", PromptSchema.Prompt},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with %Prompt{} = prompt <- Models.get_prompt(id) do
      render(conn, :show, prompt: prompt)
    end
  end

  operation(:update,
    summary: "Update a prompt",
    description: "Update an existing AI prompt",
    parameters: [
      id: [in: :path, type: :string, description: "Prompt ID", required: true]
    ],
    request_body: {"Prompt data to be updated", "application/json", PromptSchema.PromptRequest},
    responses: [
      ok: {"Ok", "application/json", PromptSchema.Prompt},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

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

  operation(:delete,
    summary: "Delete a prompt",
    description: "Delete an existing AI prompt",
    parameters: [
      id: [in: :path, type: :string, description: "Prompt ID", required: true]
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
    with %Prompt{} = prompt <- Models.get_prompt(id),
         {:ok, %Prompt{}} <- Models.delete_prompt(prompt) do
      send_resp(conn, :no_content, "")
    end
  end
end
