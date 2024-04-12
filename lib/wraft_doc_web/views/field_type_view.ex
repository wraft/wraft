defmodule WraftDocWeb.Api.V1.FieldTypeView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("field_type.json", %{field_type: field_type}) do
    %{
      id: field_type.id,
      name: field_type.name,
      description: field_type.description,
      meta: field_type.meta,
      validations:
        Enum.map(
          field_type.validations,
          &%{validation: &1.validation, error_message: &1.error_message}
        ),
      inserted_at: field_type.inserted_at,
      updated_at: field_type.updated_at
    }
  end

  def render("index.json", %{field_types: field_types}) do
    %{
      field_types: render_many(field_types, FieldTypeView, "field_type.json", as: :field_type)
    }
  end
end
