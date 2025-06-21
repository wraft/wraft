defmodule WraftDocWeb.Api.V1.ModelController do
  use WraftDocWeb, :controller
  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Models
  alias WraftDoc.Models.Model

  def index(conn, _params), do: render(conn, :index, models: Models.list_ai_models())

  def create(_conn, %{"model" => model_params}) when model_params in [nil],
    do: {:error, "Invalid model parameters"}

  def create(conn, %{"model" => model_params}) when is_map(model_params) do
    current_user = conn.assigns[:current_user]

    params =
      Map.merge(model_params, %{
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

  def create(conn, _), do: send_resp(conn, :bad_request, "Invalid request")

  def show(conn, %{"id" => id}) do
    model = Models.get_model(id)
    render(conn, :show, model: model)
  end

  def update(conn, %{"id" => id, "model" => model_params}) do
    model = Models.get_model(id)

    with {:ok, %Model{} = model} <- Models.update_model(model, model_params) do
      render(conn, :show, model: model)
    end
  end

  def delete(conn, %{"id" => id}) do
    model = Models.get_model(id)

    with {:ok, %Model{}} <- Models.delete_model(model) do
      send_resp(conn, :no_content, "")
    end
  end
end
