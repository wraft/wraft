defmodule WraftDoc.Forms.FormField do
  @moduledoc """
    form field  model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @fields [:form_id, :field_id]

  schema "form_field" do
    embeds_many(:validations, WraftDoc.Validations.Validation, on_replace: :delete)
    belongs_to(:form, WraftDoc.Forms.Form)
    belongs_to(:field, WraftDoc.Document.Field)

    timestamps()
  end

  def changeset(%FormField{} = form_field, attrs \\ %{}) do
    form_field
    |> cast(attrs, @fields)
    |> cast_embed(:validations)
    |> validate_required(@fields)
    |> unique_constraint(@fields,
      name: :form_field_unique_index,
      message: "already exist"
    )
    |> foreign_key_constraint(:form_id, message: "Please enter an existing form")
    |> foreign_key_constraint(:field_id, message: "Please enter a valid field")
  end
end
