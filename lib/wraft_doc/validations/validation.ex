defmodule WraftDoc.Validations.Validation do
  @moduledoc """
    The validation model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  embedded_schema do
    # TODO  need to change map to an ecto custom validation type
    field(:validation, :map)
    field(:error_message, :string)
  end

  def changeset(%Validation{} = validation, attrs \\ %{}) do
    validation
    |> cast(attrs, [:validation, :error_message])
    |> validate_required([:validation, :error_message])
  end
end
