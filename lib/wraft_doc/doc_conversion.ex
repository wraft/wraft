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

  @doc """
    Converts a docx file to markdown
  """
  @spec convert(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def convert(docx_path) do
    port =
      Port.open({:spawn_executable, "/usr/bin/pandoc"}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: ["-f", "docx", "-t", "markdown", docx_path]
      ])

    receive_output(port, "")
  end

  defp receive_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        receive_output(port, acc <> data)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, status}} ->
        {:error, "Pandoc failed with exit code #{status}"}
    after
      5000 ->
        Port.close(port)
        {:error, "Timeout waiting for Pandoc response"}
    end
  end
end
