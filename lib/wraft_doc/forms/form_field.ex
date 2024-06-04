defmodule WraftDoc.Forms.FormField do
  @moduledoc """
    form field  model.
  """
  alias __MODULE__
  alias WraftDoc.Validations.Validation
  use WraftDoc.Schema

  @fields [:form_id, :field_id, :order]

  schema "form_field" do
    field(:order, :integer)
    embeds_many(:validations, Validation, on_replace: :delete)
    belongs_to(:form, WraftDoc.Forms.Form)
    belongs_to(:field, WraftDoc.Document.Field)

    timestamps()
  end

  def changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, @fields)
    |> cast_embed(:validations, required: true, with: &Validation.changeset/2)
    |> validate_required(@fields)
    |> unique_constraint(@fields,
      name: :form_field_unique_index,
      message: "already exist"
    )
    |> unique_constraint(:order,
      message: "Order already exists.!",
      name: :form_field_order_field_id_index
    )
    |> foreign_key_constraint(:form_id, message: "Please enter an existing form")
    |> foreign_key_constraint(:field_id, message: "Please enter a valid field")
  end

  def update_changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, [])
    |> cast_embed(:validations, required: true, with: &Validation.changeset/2)
  end

  def order_update_changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, [:order])
    |> unique_constraint(:order,
      message: "Order already exists.!",
      name: :form_field_order_field_id_index
    )
  end
end
