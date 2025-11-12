defmodule WraftDoc.EctoType.EncryptedMapType do
  @moduledoc """
  Ecto type for storing encrypted map data in the database.

  This module provides functionality to cast, load, and dump map data
  with encryption/decryption using the underlying EncryptedBinaryType.
  """

  use Ecto.Type

  alias WraftDoc.EctoType.EncryptedBinaryType

  def type, do: :binary

  # Cast data from external sources (such as forms)
  def cast(map) when is_map(map), do: {:ok, map}
  def cast(_), do: :error

  # Load data from the database
  def load(binary) when is_binary(binary) do
    case EncryptedBinaryType.load(binary) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, map} -> {:ok, map}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  def load(_), do: :error

  # Store data in the database
  def dump(map) when is_map(map) do
    case Jason.encode(map) do
      {:ok, json} -> EncryptedBinaryType.dump(json)
      _ -> :error
    end
  end

  def dump(_), do: :error
end
