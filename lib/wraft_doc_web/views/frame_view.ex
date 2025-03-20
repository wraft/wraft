defmodule WraftDocWeb.Api.V1.FrameView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.AssetView
  alias WraftDocWeb.Api.V1.FieldTypeView
  alias WraftDocWeb.FrameThumbnailUploader

  def render("create.json", %{frame: frame}) do
    %{
      id: frame.id,
      name: frame.name,
      description: frame.description,
      type: frame.type,
      thumbnail: generate_thumbnail_url(frame),
      assets: render_many(frame.assets, AssetView, "asset.json", as: :asset),
      fields: render_many(frame.fields, __MODULE__, "field.json", as: :field),
      meta: frame.wraft_json,
      updated_at: frame.updated_at,
      inserted_at: frame.inserted_at
    }
  end

  def render("index.json", %{
        frames: frames,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      frames: render_many(frames, __MODULE__, "create.json", as: :frame),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{frame: frame}) do
    %{
      frame: render_one(frame, __MODULE__, "create.json", as: :frame)
    }
  end

  def render("field.json", %{field: field}) do
    %{
      id: field.id,
      name: field.name,
      meta: field.meta,
      description: field.description,
      field_type: render_one(field.field_type, FieldTypeView, "field_type.json", as: :field_type)
    }
  end

  defp generate_thumbnail_url(%{thumbnail: file} = frame),
    do: FrameThumbnailUploader.url({file, frame}, signed: true)
end
