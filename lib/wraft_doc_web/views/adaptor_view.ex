defmodule WraftDocWeb.Api.V1.AdaptorView do
  use WraftDocWeb, :view

  def render("index.json", %{adaptors: adaptors}) do
    %{
      adaptors: adaptors
    }
  end
end
