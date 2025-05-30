defmodule WraftDoc do
  @moduledoc """
  WraftDoc keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  A helper function to generate a signed phoenix token
  and Base64 URL encode it.
  """
  @spec create_phx_token(String.t(), any()) :: String.t()
  def create_phx_token(secret, payload, opts \\ []) do
    WraftDocWeb.Endpoint
    |> Phoenix.Token.sign(secret, payload, opts)
    |> Base.url_encode64()
  end
end
