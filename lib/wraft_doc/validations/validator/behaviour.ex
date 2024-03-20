defmodule WraftDoc.Validations.Validator.Behaviour do
  @moduledoc """
  The Validator behaviour module.

  Defines the behaviour for all validators.
  """
  @type success_message :: :ok | true
  @type error_message :: {:error, String.t()}

  @callback run(map, any()) :: boolean
  @callback validate(map(), any()) :: success_message | error_message
end
