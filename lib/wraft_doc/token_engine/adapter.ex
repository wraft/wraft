defmodule WraftDoc.TokenEngine.Adapter do
  @moduledoc """
  Behaviour for traversing and replacing tokens in different document formats.
  """

  @callback process(input :: any(), context :: map(), replacement_fn :: function()) :: any()
end
