defmodule WraftDoc.YjsWritings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "yjs-writings" do
    field(:value, :binary)
    field(:version, Ecto.Enum, values: [:v1, :v1_sv])
    field(:content_id, :binary_id)
    # belongs_to :content, WraftDoc.Document.Instance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(yjs_writings, attrs) do
    yjs_writings
    |> cast(attrs, [:content_id, :value, :version])
    |> validate_required([:content_id, :value, :version])
  end
end
