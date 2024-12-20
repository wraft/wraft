defmodule WraftDoc.YjsWritings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "yjs-writings" do
    field :value, :binary
    field :version, Ecto.Enum, values: [:v1, :v1_sv]
    field :docName, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(yjs_writings, attrs) do
    yjs_writings
    |> cast(attrs, [:docName, :value, :version])
    |> validate_required([:docName, :value, :version])
  end
end
