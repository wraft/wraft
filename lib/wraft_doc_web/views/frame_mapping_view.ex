defmodule WraftDocWeb.Api.V1.FrameMappingView do
  use WraftDocWeb, :view

  alias __MODULE__

  def render("frame_mapping.json", %{frame_mapping: frame}) do
    %{
      id: frame.id,
      frame_id: frame.frame_id,
      content_type_id: frame.content_type_id,
      mapping: render_many(frame.mapping, FrameMappingView, "mapping.json", as: :mapping),
      inserted_at: frame.inserted_at,
      updated_at: frame.updated_at
    }
  end

  def render("create.json", %{frame_mapping: frame}) do
    %{
      id: frame.id,
      frame_id: frame.frame_id,
      content_type_id: frame.content_type_id,
      mapping: render_many(frame.mapping, FrameMappingView, "mapping.json", as: :mapping),
      inserted_at: frame.inserted_at,
      updated_at: frame.updated_at
    }
  end

  def render("show.json", %{frame_mapping: frame}) do
    %{
      id: frame.id,
      frame_id: frame.frame_id,
      content_type_id: frame.content_type_id,
      mapping: render_many(frame.mapping, FrameMappingView, "mapping.json", as: :mapping),
      inserted_at: frame.inserted_at,
      updated_at: frame.updated_at
    }
  end

  def render("mapping.json", %{mapping: mapping}) do
    %{
      source: mapping.source,
      destination: mapping.destination
    }
  end

  def render("is_mapped?.json", %{}) do
    %{
      is_frame_mapped: true
    }
  end
end
