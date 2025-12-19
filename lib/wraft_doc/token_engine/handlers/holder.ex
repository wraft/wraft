defmodule WraftDoc.TokenEngine.Handlers.Holder do
  @moduledoc """
  Handler for Holder tokens (variable replacement).
  """

  alias WraftDoc.Utils.StringHelper

  # Return the updated attributes or the value to be merged into the node
  # The adapter expects the replacement to be the full node if it's a node replacement.
  # But wait, the adapter's `check_node` replaces the *entire node* with the result of `render`.
  # So we need to reconstruct the node with the new value.
  # However, `render` only gets the `data` (resolved value). It doesn't have the original node easily unless we pass it?
  # Actually, `Token` struct has `original_node`. But `render` doesn't receive the token, only `data`.
  # This is a limitation of the current Engine design if we need to preserve other node attributes.

  # Let's look at how `SmartTable` does it. It returns a new table node.
  # For `holder`, we want to update the `named` attribute.

  # We might need to change the Engine to pass the token to `render` or return a function/instruction?
  # OR, we can just return the updated node structure since we know what a "holder" node looks like.
  # But we might lose other attributes if we don't know them.

  # Let's assume for now we construct a standard holder node with the new value.
  # Based on documents.ex:
  # %{content | "attrs" => %{attrs | "named" => named_value}}

  # We don't have `content` (the original node) here.
  # We should probably update the Engine to pass the Token to render, or at least the original node?
  # BUT, I cannot change the Engine interface easily if it breaks other things
  # (though currently only SmartTable exists).

  # Let's check `TokenEngine.resolve_and_render`.
  # It calls `handler.resolve(token, context)` -> `data`.
  # Then `handler.render(data, format, options)`.

  # I can pass the original node as part of the `data` returned by `resolve`!
  # `resolve` takes `token`, so it has `token.original_node`.

  # So `resolve` will return `{:ok, %{value: value, original_node: token.original_node}}`.

  # Wait, `resolve` is supposed to be about data fetching.
  # But it seems the most pragmatic way to pass context to `render` without changing the interface.
  @behaviour WraftDoc.TokenEngine.TokenHandler

  @impl true
  def validate(params), do: {:ok, params}

  @impl true
  def resolve(token, context) do
    machine_name = token.params["machineName"] || token.params["machine_name"]
    name = token.params["name"]

    value =
      cond do
        machine_name && Map.has_key?(context, machine_name) ->
          value = Map.get(context, machine_name)
          if value != nil, do: value, else: try_name_lookup(context, name)

        name ->
          try_name_lookup(context, name)

        true ->
          nil
      end

    {:ok, %{value: value, original_node: token.original_node}}
  end

  defp try_name_lookup(context, name) when is_binary(name) do
    if Map.has_key?(context, name) do
      Map.get(context, name)
    else
      converted_name = StringHelper.convert_to_variable_name(name)
      Map.get(context, converted_name)
    end
  end

  defp try_name_lookup(_context, _name), do: nil

  @impl true
  def render(%{value: nil, original_node: node}, :prosemirror, _options), do: {:ok, node}

  def render(%{value: value, original_node: node}, :prosemirror, _options) do
    attrs = node["attrs"] || %{}
    updated_attrs = Map.put(attrs, "named", value)
    {:ok, Map.put(node, "attrs", updated_attrs)}
  end

  def render(_data, _format, _options), do: {:error, :unsupported_format}
end
