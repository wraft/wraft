defmodule WraftDoc.YDocuments do
  use Ecto.Schema
  import Ecto.Changeset

  schema "y_documents" do
    field(:value, :binary)
    field(:version, Ecto.Enum, values: [:v1, :v1_sv])
    field(:content_id, :binary_id)
    # belongs_to :content, WraftDoc.Document.Instance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(y_documents, attrs) do
    y_documents
    |> cast(attrs, [:content_id, :value, :version])
    |> validate_required([:content_id, :value, :version])
  end
end
