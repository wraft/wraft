defmodule WraftDocWeb.AdminNext.Translator do
  @moduledoc """
  Translator hooks for Backpex. The admin UI is English-only, so these are
  identity-with-interpolation rather than real Gettext routes. Configured
  via `config :backpex, translator_function:` / `error_translator_function:`.
  """

  @doc """
  Translates a Backpex UI string. Returns the message verbatim, interpolating
  any `%{key}` bindings.
  """
  def translate({msg, bindings}) do
    Enum.reduce(bindings, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def translate(msg) when is_binary(msg), do: msg

  @doc """
  Translates a single Ecto changeset error (msg + opts pair).
  """
  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
