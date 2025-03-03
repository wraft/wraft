defmodule WraftDoc.Utils.CSVHelper do
  @moduledoc """
  A helper module for decoding CSV files and updating keys.
  """

  @spec decode_csv(String.t(), list) :: list
  def decode_csv(path, mapping_keys) do
    path
    |> File.stream!()
    |> Stream.drop(1)
    |> CSV.decode!(headers: mapping_keys)
    |> Enum.to_list()
  end

  @spec update_keys(map, map) :: map
  def update_keys(map, mapping) do
    Enum.reduce(mapping, %{}, fn {old_key, new_key}, acc ->
      Map.put(acc, new_key, Map.get(map, old_key))
    end)
  end

  @spec transform_csv(String.t(), map) :: list
  def transform_csv(path, mapping) do
    path
    |> decode_csv(Map.keys(mapping))
    |> Enum.map(&update_keys(&1, mapping))
  end
end
