defmodule WraftDoc.Utils.TokenGenerator do
  @moduledoc """
  Utility for generating secure random tokens.
  """

  @doc """
  Generate a random token of specified length.
  Default length is 32 characters.
  """
  @spec generate(integer) :: String.t()
  def generate(length \\ 32) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end
end
