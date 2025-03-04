defmodule WraftDoc.DocConversion do
  @moduledoc false

  alias WraftDocWeb.Funda

  @doc """
  Converts a document from one format to another
  """
  def doc_conversion(template_path, params) do
    # "/Users/sk/offerletter.md"
    content = File.read!(template_path)
    a = Enum.reduce(params, content, fn {k, v}, acc -> replace_content(k, v, acc) end)
    updated_file_path = "/Users/sk/offerletter2.md"
    File.write(updated_file_path, a)
    Funda.convert(updated_file_path, params["new_format"])
  end

  def replace_content(key, value, content) do
    String.replace(content, "[#{key}]", value)
  end
end
