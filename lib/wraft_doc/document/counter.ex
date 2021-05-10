defmodule WraftDoc.Document.Counter do
  @moduledoc """
  The Counter model.
  """
  use WraftDoc.Schema

  schema "counter" do
    field(:subject, :string)
    field(:count, :integer)
    timestamps()
  end

  def changeset(counter, attrs \\ %{}) do
    counter |> cast(attrs, [:subject, :count]) |> validate_required([:subject, :count])
  end

  def update_changeset(counter, attrs \\ %{}) do
    counter |> cast(attrs, [:count]) |> validate_required([:count])
  end
end
