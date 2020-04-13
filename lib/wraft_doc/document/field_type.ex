defmodule WraftDoc.Document.FieldType do
  @moduledoc """
    The field type model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "field_type" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:description, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    has_many(:fields, WraftDoc.Document.ContentTypeField)
    timestamps()
  end

  def changeset(field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> unique_constraint(:name,
      message: "Field type with the same name exists. Use another name.!",
      name: :field_type_unique_index
    )
  end
end
