defmodule WraftDocWeb.Api.V1.ModelView do
  alias WraftDoc.Models.Model

  @doc """
  Renders a list of models.
  """
  def index(%{models: models}) do
    %{data: for(model <- models, do: data(model))}
  end

  @doc """
  Renders a single model.
  """
  def show(%{model: model}) do
    %{data: data(model)}
  end

  defp data(%Model{} = model) do
    %{
      id: model.id,
      name: model.name,
      description: model.description,
      endpoint_url: model.endpoint_url,
      is_default: model.is_default,
      is_local: model.is_local,
      is_thinking_model: model.is_thinking_model,
      daily_request_limit: model.daily_request_limit,
      daily_token_limit: model.daily_token_limit,
      auth_key: mask_auth_key(model.auth_key),
      status: model.status,
      model_type: model.model_type,
      model_version: model.model_version
    }
  end

  defp mask_auth_key(nil), do: nil
  defp mask_auth_key(:error), do: %{"error" => "Key error, please update key"}

  defp mask_auth_key(key) do
    masked_part = String.duplicate("*", byte_size(key) - 4)
    visible_part = String.slice(key, -4, 4)

    masked_part <> visible_part
  end
end
