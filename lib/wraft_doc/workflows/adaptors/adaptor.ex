defmodule WraftDoc.Workflows.Adaptors.Adaptor do
  @moduledoc """
  Behavior for workflow adaptors.

  Adaptors connect workflows to external systems and services.
  Each adaptor must implement this behavior.
  """

  @type config :: map()
  @type input_data :: map()
  @type output_data :: map()
  @type credentials :: map() | nil

  @callback execute(config(), input_data(), credentials()) ::
              {:ok, output_data()} | {:error, term()}

  @callback validate_config(config()) :: :ok | {:error, term()}

  @optional_callbacks [validate_config: 1]
end
