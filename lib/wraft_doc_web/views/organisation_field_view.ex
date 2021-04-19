defmodule WraftDocWeb.Api.V1.OrganisationFieldView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{FieldTypeView, OrganisationFieldView}

  def render("index.json", %{
        organisation_fields: organisation_fields,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      organisation_fields:
        render_many(organisation_fields, OrganisationFieldView, "organisation_field.json"),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{organisation_field: organisation_field}) do
    render_one(organisation_field, OrganisationFieldView, "organisation_field.json")
  end

  def render("organisation_field.json", %{organisation_field: organisation_field}) do
    %{
      uuid: organisation_field.uuid,
      name: organisation_field.name,
      meta: organisation_field.meta,
      description: organisation_field.description,
      field_type: render_one(organisation_field.field_type, FieldTypeView, "field_type.json"),
      inserted_at: organisation_field.inserted_at,
      updated_at: organisation_field.updated_at
    }
  end
end
