defmodule WraftDoc.TokenEngine.Handlers.Signature do
  @moduledoc """
  Handler for Signature Field tokens.
  """

  @behaviour WraftDoc.TokenEngine.TokenHandler

  @impl true
  def validate(params) do
    {:ok, params}
  end

  @impl true
  def resolve(token, _context) do
    {:ok,
     %{
       width: Map.get(token.params, "width", "200"),
       height: Map.get(token.params, "height", "100")
     }}
  end

  @impl true
  def render(data, :markdown, _options) do
    {:ok, "[SIGNATURE_FIELD width=#{data.width} height=#{data.height}]"}
  end

  @impl true
  def render(data, :prosemirror, _options) do
    {:ok,
     %{
       "type" => "signature",
       "attrs" => %{
         "width" => data.width,
         "height" => data.height
       }
     }}
  end

  @impl true
  def render(_data, _format, _options), do: {:error, :unsupported_format}
end
