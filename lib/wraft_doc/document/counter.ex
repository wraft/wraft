defmodule WraftDoc.Document.Counter do
  @moduledoc """
  The Counter model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "counter" do
    field(:subject, :string)
    field(:count, :integer)
  end

  def changeset(counter, attrs \\ %{}) do
    counter |> cast(attrs, [:subject, :count]) |> validate_required([:subject, :count])
  end

  def update_changeset(counter, attrs \\ %{}) do
    counter |> cast(attrs, [:count]) |> validate_required([:count])
  end
end
