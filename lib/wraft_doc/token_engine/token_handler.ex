defmodule WraftDoc.TokenEngine.TokenHandler do
  @moduledoc """
  Behaviour for handling specific token types.
  """

  alias WraftDoc.TokenEngine.Token

  @callback validate(params :: map()) :: {:ok, map()} | {:error, any()}
  @callback resolve(token :: Token.t(), context :: map()) :: {:ok, any()} | :ignore
  @callback render(data :: any(), format :: atom(), options :: keyword()) ::
              {:ok, any()} | {:error, any()}
end
