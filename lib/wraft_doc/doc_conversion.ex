defmodule WraftDoc.DocConversion do
  @moduledoc false

  alias WraftDocWeb.Funda

  @conversion_timeout 5000

  # 1. Check if a PANDOC_PATH environment variable is set
  # 2. Use System.find_executable to search in PATH
  # 3. Use common Docker installation paths as fallbacks
  @pandoc_executable System.get_env("PANDOC_PATH") ||
                       System.find_executable("pandoc") ||
                       "/usr/bin/pandoc"

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
    case @pandoc_executable do
      nil ->
        {:error, "Pandoc executable not found in system PATH"}

      pandoc_path ->
        port =
          Port.open({:spawn_executable, pandoc_path}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: ["-f", "docx", "-t", "gfm", "--wrap=none", docx_path]
          ])

        receive_output(port, "")
    end
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
      @conversion_timeout ->
        Port.close(port)
        {:error, "Timeout waiting for Pandoc response"}
    end
  end
end
