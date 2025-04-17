defmodule WraftDocWeb.Api.V1.GlobalImportView do
  use WraftDocWeb, :view

  def render("global_file_preview.json", %{
        global_file_preview: %{meta: meta, file_details: file_details}
      }) do
    %{
      meta: meta,
      file_details: file_details
    }
  end

  def render("global_file_validation.json", %{
        message: message
      }) do
    %{
      message: message
    }
  end

  def render("global_file_validation.json", %{
        message: message,
        result: result
      }) do
    %{
      message: message,
      result: result
    }
  end
end
