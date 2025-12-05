defmodule WraftDoc.TokenEngine.Registry do
  @moduledoc """
  Registry for mapping token types to their handler modules.
  """

  # In a real application, this might be backed by a GenServer or persistent_term
  # For now, we'll use a simple map or configuration.
  # Let's use a simple function pattern matching or map for simplicity and extensibility.

  @handlers %{
    "SMART_TABLE" => WraftDoc.TokenEngine.Handlers.SmartTable,
    "SMART_DYNAMIC" => WraftDoc.TokenEngine.Handlers.SmartBlock,
    "SMART_TABLE_PLACEHOLDER" => WraftDoc.TokenEngine.Handlers.SmartTable,
    "SIGNATURE_FIELD" => WraftDoc.TokenEngine.Handlers.Signature,
    "holder" => WraftDoc.TokenEngine.Handlers.Holder
  }

  def lookup(type) when is_binary(type) do
    Map.get(@handlers, type)
  end

  def lookup(type) when is_atom(type) do
    lookup(Atom.to_string(type))
  end
end
