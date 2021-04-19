defmodule WraftDocWeb.Api.V1.ContentTypeView do
  use WraftDocWeb, :view

  alias __MODULE__
  alias WraftDocWeb.Api.V1.{FieldTypeView, FlowView, LayoutView, RoleView, UserView}

  def render("create.json", %{content_type: c_type}) do
    %{
      id: c_type.uuid,
      name: c_type.name,
      decription: c_type.description,
      fields: render_many(c_type.fields, ContentTypeView, "field.json", as: :field),
      color: c_type.color,
      prefix: c_type.prefix,
      inserted_at: c_type.inserted_at,
      updated_at: c_type.updated_at,
      layout: render_one(c_type.layout, LayoutView, "layout.json", as: :doc_layout),
      flow: render_one(c_type.flow, FlowView, "flow.json", as: :flow)
    }
  end

  def render("role_content_type.json", %{content_type: c_type}) do
    %{
      id: c_type.uuid,
      name: c_type.name,
      decription: c_type.description,
      color: c_type.color,
      prefix: c_type.prefix,
      inserted_at: c_type.inserted_at,
      updated_at: c_type.updated_at
    }
  end

  def render("role_content_types.json", %{content_type: content_type}) do
    %{
      id: content_type.uuid,
      name: content_type.name,
      decription: content_type.description,
      color: content_type.color,
      prefix: content_type.prefix,
      inserted_at: content_type.inserted_at,
      updated_at: content_type.updated_at,
      role: render_many(content_type.roles, RoleView, "role.json", as: :role)
    }
  end

  def render("index.json", %{
        content_types: content_types,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      content_types:
        render_many(content_types, ContentTypeView, "create.json", as: :content_type),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{content_type: content_type}) do
    %{
      content_type:
        render_one(content_type, ContentTypeView, "show_c_type.json", as: :content_type),
      creator: render_one(content_type.creator, UserView, "user.json", as: :user)
    }
  end

  def render("content_type.json", %{content_type: c_type}) do
    %{
      id: c_type.uuid,
      name: c_type.name,
      decription: c_type.description,
      color: c_type.color,
      prefix: c_type.prefix,
      inserted_at: c_type.inserted_at,
      updated_at: c_type.updated_at
    }
  end

  def render("c_type_with_layout.json", %{content_type: c_type}) do
    %{
      id: c_type.uuid,
      name: c_type.name,
      decription: c_type.description,
      color: c_type.color,
      prefix: c_type.prefix,
      inserted_at: c_type.inserted_at,
      updated_at: c_type.updated_at,
      layout: render_one(c_type.layout, LayoutView, "layout.json", as: :doc_layout)
    }
  end

  def render("c_type_and_fields.json", %{c_type: c_type}) do
    %{
      id: c_type.uuid,
      name: c_type.name,
      decription: c_type.description,
      fields: render_many(c_type.fields, ContentTypeView, "field.json", as: :field),
      color: c_type.color,
      prefix: c_type.prefix,
      inserted_at: c_type.inserted_at,
      updated_at: c_type.updated_at
    }
  end

  def render("show_c_type.json", %{content_type: c_type}) do
    %{
      id: c_type.uuid,
      name: c_type.name,
      decription: c_type.description,
      fields: render_many(c_type.fields, ContentTypeView, "field.json", as: :field),
      color: c_type.color,
      prefix: c_type.prefix,
      inserted_at: c_type.inserted_at,
      updated_at: c_type.updated_at,
      layout: render_one(c_type.layout, LayoutView, "layout.json", as: :doc_layout),
      flow: render_one(c_type.flow, FlowView, "flow_and_states.json", as: :flow)
    }
  end

  def render("field.json", %{field: field}) do
    %{
      id: field.uuid,
      name: field.name,
      field_type: render_one(field.field_type, FieldTypeView, "field_type.json", as: :field_type)
    }
  end

  def render("bulk.json", %{}) do
    %{
      info: "Documents will be generated soon."
    }
  end
end
