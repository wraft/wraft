defmodule WraftDocWeb.ResourceAdmin do
  @moduledoc """
  Module for resource admin
  """
  alias WraftDoc.Authorization.Resource

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      category: %{name: "Category", value: fn x -> category(x) end},
      action: %{name: "Action", value: fn x -> action(x) end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      version: %{label: "Version", choices: [{"WraftDocWeb.Api.V1", "WraftDocWeb.Api.V1"}]},
      controller: %{label: "Controller"},
      action: %{action: "Action"}
    ]
  end

  # def create_changeset(schema, attrs) do
  #   category = "Elixir.#{attrs["version"]}.#{attrs["controller"]}" |> String.to_atom()
  #   action = attrs["action"] || "" |> String.downcase() |> String.to_atom()
  #   attrs = %{"name" => attrs["name"], "action" => action, "category" => category}

  # end

  def before_insert(conn, changeset) do
    attrs = conn.body_params["resource"]
    category = String.to_atom("Elixir.#{attrs["version"]}.#{attrs["controller"]}")
    action = attrs["action"] || "" |> String.downcase() |> String.to_atom()
    attrs = %{"name" => attrs["name"], "action" => action, "category" => category}
    changeset = Resource.changeset(changeset.data, attrs)
    {:ok, changeset}
  end

  defp category(%Resource{category: category}) do
    category |> to_string() |> String.replace("Elixir.", "")
  end

  defp category(_), do: ""

  defp action(%Resource{action: action}) do
    to_string(action)
  end

  defp action(_), do: ""
end
