defmodule WraftDocWeb.Api.V1.ActionView do
  use WraftDocWeb, :view

  def render("index.json", %{actions: actions, categories: categories}) do
    %{
      actions: Enum.map(actions, &format_action/1),
      categories: categories
    }
  end

  def render("show.json", %{action: action}) do
    format_action(action)
  end

  defp format_action(action) do
    %{
      id: WraftDoc.Workflows.Actions.Registry.get_action_id(action),
      adapter: action.adapter,
      name: action.name,
      description: action.description,
      icon: action.icon,
      category: action.category,
      default_config: action.default_config,
      required_fields: action.required_fields,
      input_fields: action.input_fields
    }
  end
end
