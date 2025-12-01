defmodule WraftDoc.TokenEngine.Adapters.Markdown do
  @moduledoc """
  Adapter for replacing tokens in Markdown content.
  """

  @behaviour WraftDoc.TokenEngine.Adapter

  alias WraftDoc.TokenEngine.Token
  alias WraftDoc.TokenEngine.Utils

  # Regex to match [TYPE:params]
  # Captures:
  # 1. TYPE (e.g., SMART_TABLE)
  # 2. params (e.g., id=123 width=100)
  @token_regex ~r/\[([A-Z_]+)(?::(.*?))?\]/

  @impl true
  def process(input, _context, replacement_fn) when is_binary(input) do
    Regex.replace(@token_regex, input, fn _full, type, params_str ->
      token = build_token(input, type, params_str)
      apply_replacement(token, params_str, replacement_fn)
    end)
  end

  def process(input, _context, _replacement_fn), do: input

  defp build_token(input, type, params_str) do
    params = Utils.parse_params(params_str || "")

    %Token{
      type: type,
      params: params,
      original_node: input,
      source: :markdown
    }
  end

  defp apply_replacement(token, params_str, replacement_fn) do
    case replacement_fn.(token) do
      {:ok, replacement} ->
        to_string(replacement)

      :ignore ->
        render_original(token.type, params_str)
    end
  end

  defp render_original(type, nil), do: "[#{type}]"
  defp render_original(type, params_str), do: "[#{type}:#{params_str}]"
end
