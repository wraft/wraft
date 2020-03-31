defmodule WraftDoc.Document.FieldType do
  @moduledoc """
    The field type model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "field_type" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    belongs_to(:creator, WraftDoc.Account.User)
    has_many(:fields, WraftDoc.Document.ContentTypeField)
    has_many(:content_types, through: [:fields, :content_type])
    timestamps()
  end

  def changeset(field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name,
      message: "Field type with the same name exists. Use another name.!",
      name: :field_type_unique_index
    )
  end
end
