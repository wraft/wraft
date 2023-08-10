defmodule WraftDoc.EctoType.AtomType do
  @moduledoc """
  An ecto type specified to store atomes
  """
  use Ecto.Type

  def type, do: :string

  def cast(module) when is_binary(module) do
    {:ok, String.to_atom(module)}
  end

  def cast(module) when is_atom(module) and not is_nil(module) do
    {:ok, module}
  end

  def cast(_), do: :error

  def load(string) when is_binary(string) do
    {:ok, String.to_atom(string)}
  end

  def load(_), do: :error

  def dump(module) when is_atom(module) and not is_nil(module) do
    {:ok, to_string(module)}
  end

  def dump(_), do: :error
end
