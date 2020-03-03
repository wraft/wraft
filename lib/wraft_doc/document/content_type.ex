defmodule WraftDoc.Document.ContentType do
  @moduledoc """
    The content type model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.ContentType

  schema "content_type" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:description, :string)
    field(:fields, :map)
    field(:prefix, :string)
    belongs_to(:layout, WraftDoc.Document.Layout)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:instances, WraftDoc.Document.Instance)

    timestamps()
  end

  def changeset(%ContentType{} = content_type, attrs \\ %{}) do
    content_type
    |> cast(attrs, [:name, :description, :fields, :prefix, :organisation_id])
    |> validate_required([:name, :description, :fields, :prefix, :organisation_id])
    |> unique_constraint(:name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
  end

  def update_changeset(%ContentType{} = content_type, attrs \\ %{}) do
    content_type
    |> cast(attrs, [:name, :description, :fields, :layout_id, :prefix])
    |> validate_required([:name, :description, :fields, :layout_id, :prefix])
    |> unique_constraint(:name,
      message: "Content type with the same name under your organisation exists.!",
      name: :content_type_organisation_unique_index
    )
    |> validate_length(:prefix, min: 2, max: 6)
  end
end
