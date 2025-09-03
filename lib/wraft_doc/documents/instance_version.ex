defmodule WraftDoc.Documents.Instance.Version do
  @moduledoc """
    The instance version model.
  """
  use WraftDoc.Schema
  alias __MODULE__

  @fields [
    :version_number,
    :raw,
    :serialized,
    :author_id,
    :type,
    :naration,
    :content_id,
    :current_version
  ]

  schema "version" do
    field(:version_number, :integer)
    field(:type, Ecto.Enum, values: [:build, :save])
    field(:raw, :string)
    field(:serialized, :map, default: %{})
    field(:naration, :string)
    field(:current_version, :boolean, default: false)

    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:author, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%Version{} = version, attrs \\ %{}) do
    version
    |> cast(attrs, @fields)
    |> validate_required(@fields -- [:naration, :content_id])
    |> unique_constraint(:version_number,
      name: :version_unique_index,
      message: "Version number already exists"
    )
  end
end
