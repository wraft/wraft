defmodule WraftDoc.TokenEngine.Adapters.Prosemirror do
  @moduledoc """
  Adapter for replacing tokens in ProseMirror JSON content.
  """

  @behaviour WraftDoc.TokenEngine.Adapter

  alias WraftDoc.TokenEngine.Token

  @impl true
  def process(input, context, replacement_fn) when is_map(input) do
    traverse(input, context, replacement_fn)
  end

  def process(input, _context, _replacement_fn), do: input

  defp traverse(%{"content" => content} = node, context, replacement_fn) when is_list(content) do
    # First traverse children
    new_content = Enum.map(content, &traverse(&1, context, replacement_fn))
    node = Map.put(node, "content", new_content)

    # Then check if the node itself is a token candidate
    check_node(node, context, replacement_fn)
  end

  defp traverse(node, context, replacement_fn) when is_map(node) do
    check_node(node, context, replacement_fn)
  end

  defp traverse(other, _context, _replacement_fn), do: other

  defp check_node(node, _context, replacement_fn) do
    case identify_token(node) do
      {:ok, type, params} ->
        token = %Token{
          type: type,
          params: params,
          original_node: node,
          source: :prosemirror
        }

        case replacement_fn.(token) do
          {:ok, replacement} -> replacement
          :ignore -> node
        end

      :error ->
        node
    end
  end

  # Identify known token types from ProseMirror nodes
  defp identify_token(%{"type" => "smartTableWrapper", "attrs" => attrs}) do
    {:ok, "SMART_TABLE", attrs}
  end

  defp identify_token(%{"type" => "signature", "attrs" => attrs}) do
    {:ok, "SIGNATURE_FIELD", attrs}
  end

  # Add more identifications here as needed or make this extensible via config
  defp identify_token(_node), do: :error
end
