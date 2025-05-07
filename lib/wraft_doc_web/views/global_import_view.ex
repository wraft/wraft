defmodule WraftDocWeb.Api.V1.GlobalImportView do
  use WraftDocWeb, :view

  def render("pre_import_global_file.json", %{
        response: %{wraft_json: meta, file_details: file_details, errors: errors}
      }) do
    %{
      data: %{
        meta: meta,
        file_details: file_details
      },
      errors: errors
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
