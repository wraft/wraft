defmodule WraftDoc.TokenEngine.Utils do
  @moduledoc """
  Helper functions for the Token Engine.
  """

  @doc """
  Parses a parameter string like "key1:value1 key2:value2" into a map.
  """
  def parse_params(param_string) when is_binary(param_string) do
    param_string
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce(%{}, fn part, acc ->
      case String.split(part, ":", parts: 2) do
        [key, value] -> Map.put(acc, key, value)
        # Handle flags
        [key] -> Map.put(acc, key, true)
      end
    end)
  end

  def parse_params(_), do: %{}
end
