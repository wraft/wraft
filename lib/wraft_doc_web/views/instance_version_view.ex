defmodule WraftDocWeb.Api.V1.InstanceVersionView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{InstanceView, UserView}

  def render("version.json", %{version: version}) do
    %{
      id: version.id,
      version_number: version.version_number,
      raw: version.raw,
      serialised: version.serialized,
      naration: version.naration,
      author: render_one(version.author, UserView, "user.json", as: :user),
      inserted_at: version.inserted_at,
      updated_at: version.updated_at
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

  def render("line.json", %{line: line}) do
    line
  end
end
