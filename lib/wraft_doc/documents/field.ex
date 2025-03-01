defmodule WraftDoc.Documents.Field do
  @moduledoc """
  The field schema.
  """
  alias __MODULE__
  use WraftDoc.Schema

  schema "field" do
    field(:name, :string)
    field(:meta, :map, default: %{})
    field(:description, :string)
    has_many(:form_fields, WraftDoc.Forms.FormField)
    has_many(:forms, through: [:form_fields, :form])
    has_many(:content_type_fields, WraftDoc.ContentTypes.ContentTypeField)
    has_many(:content_types, through: [:content_type_fields, :content_type])
    belongs_to(:field_type, WraftDoc.Documents.FieldType)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Field{} = field, attrs \\ %{}) do
    field
    |> cast(attrs, [:name, :meta, :description, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end

  def update_changeset(%Field{} = field, attrs \\ %{}) do
    field
    |> cast(attrs, [:name, :meta, :description, :field_type_id])
    |> validate_required([:name, :meta, :field_type_id])
  end
end
