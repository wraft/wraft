defmodule WraftDocWeb.Api.V1.DocumentView do
  use WraftDocWeb, :view

  def render("import_docx.json", %{prosemirror_data: prosemirror_data}) do
    %{
      prosemirror: prosemirror_data
    }
  end
end
