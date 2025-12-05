defmodule WraftDoc.TokenEngine.Handlers.SmartBlock do
  @moduledoc """
  Handler for Smart Block tokens.
  """

  @behaviour WraftDoc.TokenEngine.TokenHandler

  @impl true
  def validate(params), do: {:ok, params}

  @impl true
  @doc """
    Context is expected to be the map of smart_blocks, or a map containing "smart_blocks" key
    Based on template_adaptor.ex: incoming = smart_blocks[block_name]

    We'll assume context IS the smart_blocks map for simplicity, or we check for a key.
    Let's support both for flexibility.
  """
  def resolve(%{original_node: original_node} = _token, data) do
    {:ok, %{data: data, original_node: original_node}}
  end

  @impl true
  def render(%{data: "", original_node: node}, :prosemirror, _options) do
    {:ok, node}
  end

  def render(%{data: nil, original_node: node}, :prosemirror, _options) do
    {:ok, node}
  end

  def render(%{data: data, original_node: node}, :prosemirror, _options) when is_map(data) do
    node = render_smart_block(node, data)
    {:ok, node}
  end

  def render(_data, _format, _options), do: {:error, :unsupported_format}

  defp render_smart_block(
         %{
           "type" => "dyna",
           "attrs" => %{
             "activeClass" => "",
             "field" => field,
             "inactiveClass" => "",
             "operator" => operator,
             "showWhenInactive" => false,
             "value" => value
           },
           "content" => [content]
         } = _node,
         data
       )
       when is_map(data) do
    field_value = Map.get(data, field, "")
    operator = get_operator(operator)

    if compare(field_value, operator, value) do
      content
    else
      %{
        "type" => "paragraph",
        "content" => [
          %{
            "type" => "text",
            "text" => "No data available"
          }
        ]
      }
    end
  end

  defp get_operator(operator) do
    case operator do
      "equals" -> "=="
      "not_equals" -> "!="
      "greater_than" -> ">"
      "less_than" -> "<"
      _ -> "=="
    end
  end

  defp compare(left, op, right) do
    case op do
      "equals" ->
        left == right

      "not_equals" ->
        left != right

      "greater_than" ->
        compare_numbers(left, right, :gt)

      "less_than" ->
        compare_numbers(left, right, :lt)

      _ ->
        left == right
    end
  end

  defp compare_numbers(left, right, type) do
    with {l, _} <- Float.parse(to_string(left)),
         {r, _} <- Float.parse(to_string(right)) do
      case type do
        :gt -> l > r
        :lt -> l < r
      end
    else
      _ -> false
    end
  end
end
