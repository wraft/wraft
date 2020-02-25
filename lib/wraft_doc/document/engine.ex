defmodule WraftDoc.Document.Engine do
  @moduledoc """
    The engine model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Engine

  schema "engine" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:api_route, :string)
    timestamps()
  end

  def changeset(%Engine{} = engine, attrs \\ %{}) do
    engine |> cast(attrs, [:name, :api_route]) |> validate_required([:name])
  end
end
