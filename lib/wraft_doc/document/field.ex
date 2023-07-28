defmodule WraftDoc.Document.Field do
  @moduledoc """
  The field schema.
  """
  alias __MODULE__
  use WraftDoc.Schema

  schema "field" do
    field(:name, :string)
    field(:meta, :map)
    field(:description, :string)
    has_many(:form_fields, WraftDoc.Forms.FormField)
    has_many(:forms, through: [:form_fields, :form])
    has_many(:content_type_fields, WraftDoc.Document.ContentTypeField)
    has_many(:content_types, through: [:content_type_fields, :content_type])
    # TODO need to remove this since we are switching into many to many relationship
    # TODO move the content type id from this table to new contentype many to many field table
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:field_type, WraftDoc.Document.FieldType)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Field{} = field, attrs \\ %{}) do
    field
    |> cast(attrs, [:name, :meta])
    |> validate_required([:name])
    # TODO update the constraint name as the table name is changed to field
    |> unique_constraint(:name,
      message: "Field type already added.!",
      name: :content_type_field_unique_index
    )
  end
end
