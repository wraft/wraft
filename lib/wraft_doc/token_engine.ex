defmodule WraftDoc.TokenEngine do
  @moduledoc """
  Main entry point for the Token Replacement Engine.
  """

  alias WraftDoc.TokenEngine.Registry
  alias WraftDoc.TokenEngine.Token

  @doc """
  Replaces tokens in the given input using the specified adapter.

  ## Arguments

  * `input` - The document content (String for Markdown, Map for ProseMirror).
  * `adapter` - The adapter module to use (e.g., `WraftDoc.TokenEngine.Adapters.Markdown`).
  * `context` - A map of context data to be passed to resolvers.
  * `options` - Keyword list of options, including `render_options`.

  ## Returns

  The input with tokens replaced.
  """
  def replace(input, adapter, context \\ %{}, options \\ []) do
    replacement_fn = fn token ->
      resolve_and_render(token, context, options)
    end

    adapter.process(input, context, replacement_fn)
  end

  defp resolve_and_render(%Token{type: type} = token, context, options) do
    case Registry.lookup(type) do
      nil ->
        :ignore

      handler ->
        with {:ok, valid_params} <- handler.validate(token.params),
             token = %{token | params: valid_params},
             {:ok, data} <- handler.resolve(token, context) do
          format = get_format_from_source(token.source)
          render_options = Keyword.get(options, :render_options, [])

          handler.render(data, format, render_options)
        else
          _ -> :ignore
        end
    end
  end

  defp get_format_from_source(:markdown), do: :markdown
  defp get_format_from_source(:prosemirror), do: :prosemirror
  defp get_format_from_source(_), do: :unknown
end
