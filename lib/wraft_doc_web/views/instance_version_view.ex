defmodule WraftDocWeb.Api.V1.InstanceVersionView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{InstanceView, UserView}

  def render("version.json", %{version: version}) do
    %{
      id: version.id,
      version_number: version.version_number,
      naration: version.naration,
      author: render_one(version.author, UserView, "actor.json", as: :user),
      current_version: version.current_version,
      inserted_at: version.inserted_at
    }
  end

  def render("versions.json", %{
        versions: versions,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      versions: render_many(versions, __MODULE__, "version.json", as: :version),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{version: version}) do
    %{
      version: render_one(version, __MODULE__, "version.json", as: :version),
      content: render_one(version.content, InstanceView, "instance.json", as: :instance)
    }
  end

  def render("change.json", %{change: change}) do
    %{
      ins: render_many(change.ins, __MODULE__, "line.json", as: :line),
      del: render_many(change.del, __MODULE__, "line.json", as: :line)
    }
  end

  def render("line.json", %{line: line}), do: line

  def render("comparison.json", %{comparison: comparison}), do: comparison
end
