defmodule WraftDoc.TokenEngine.Token do
  @moduledoc """
  Represents a token found in a document.
  """

  @type t :: %__MODULE__{
          type: atom(),
          id: String.t() | nil,
          params: map(),
          original_node: any(),
          source: atom()
        }

  defstruct [:type, :id, :params, :original_node, :source]
end
