defmodule WraftDocWeb.Api.V1.PromptsController do
  use WraftDocWeb, :controller
  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Models
  alias WraftDoc.Models.Prompt

  def index(conn, _params) do
    prompts = Models.list_prompts()
    render(conn, :index, prompts: prompts)
  end

  def create(conn, params) do
    with {:ok, %Prompt{id: id} = prompts} <- Models.create_prompts(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/prompts/#{id}")
      |> render(:show, prompts: prompts)
    end
  end

  def show(conn, %{"id" => id}) do
    prompts = Models.get_prompt(id)
    render(conn, :show, prompts: prompts)
  end

  def update(conn, %{"id" => id, "prompts" => prompts_params}) do
    prompts = Models.get_prompt(id)

    with {:ok, %Prompt{} = prompts} <- Models.update_prompts(prompts, prompts_params) do
      render(conn, :show, prompts: prompts)
    end
  end

  def delete(conn, %{"id" => id}) do
    prompts = Models.get_prompt(id)

    with {:ok, %Prompt{}} <- Models.delete_prompts(prompts) do
      send_resp(conn, :no_content, "")
    end
  end
end
