defmodule WraftDoc.DocConversion do
  alias WraftDocWeb.Funda

  def doc_conversion(template_path, params) do
    # "/Users/sk/offerletter.md"
    content = File.read!(template_path)
    a = params |> Enum.reduce(content, fn {k, v}, acc -> replace_content(k, v, acc) end)
    updated_file_path = "/Users/sk/offerletter2.md"
    updated_file_path |> File.write(a)
    updated_file_path |> Funda.convert(params["new_format"])
  end

  def replace_content(key, value, content) do
    content |> String.replace("[#{key}]", value)
  end
end
