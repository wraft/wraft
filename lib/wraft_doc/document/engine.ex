defmodule WraftDoc.Document.Engine do
  @moduledoc """
    The engine model.
  """
  use WraftDoc.Schema

  alias WraftDoc.Document.Engine

  schema "engine" do
    field(:name, :string, null: false)
    field(:api_route, :string)
    timestamps()
  end

  def changeset(%Engine{} = engine, attrs \\ %{}) do
    engine
    |> cast(attrs, [:name, :api_route])
    |> validate_required([:name])
    |> unique_constraint(:name, message: "Engine name already taken.! Try another email.")
  end
end
