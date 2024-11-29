defmodule WraftDocWeb.Api.V1.FrameView do
  use WraftDocWeb, :view

  alias __MODULE__

  def render("create.json", %{frame: frame}) do
    %{
      id: frame.id,
      name: frame.name,
      frame_file: frame.frame_file,
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
      frames: render_many(frames, FrameView, "create.json", as: :frame),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{frame: frame}) do
    %{
      frame: render_one(frame, FrameView, "create.json", as: :frame)
    }
  end
end
