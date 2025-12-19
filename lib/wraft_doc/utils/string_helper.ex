defmodule WraftDoc.Utils.StringHelper do
  @moduledoc """
  Utility functions for string manipulation and conversion.
  """

  @doc """
  Converts a string to a variable name format (lowercase with underscores).

  Used for normalizing field names and identifiers across the application.

  ## Examples

      iex> WraftDoc.Utils.StringHelper.convert_to_variable_name("First Name")
      "first_name"
      
      iex> WraftDoc.Utils.StringHelper.convert_to_variable_name("User-Email-Address")
      "user_email_address"
      
      iex> WraftDoc.Utils.StringHelper.convert_to_variable_name("price_$$$")
      "price"
  """
  @spec convert_to_variable_name(binary()) :: binary()
  def convert_to_variable_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  def convert_to_variable_name(_), do: ""
end
