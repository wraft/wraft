defmodule WraftDoc.Validations.Validation do
  @moduledoc """
    The validation model.
  """
  alias __MODULE__
  alias WraftDoc.EctoType.ValidationType
  use WraftDoc.Schema

  embedded_schema do
    field(:validation, ValidationType)
    field(:error_message, :string)
  end

  def changeset(%Validation{} = validation, attrs \\ %{}) do
    validation
    |> cast(attrs, [:validation, :error_message])
    |> validate_required([:validation, :error_message])
  end
end
