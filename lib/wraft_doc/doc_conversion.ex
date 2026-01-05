defmodule WraftDoc.DocConversion do
  @moduledoc false

  alias WraftDocWeb.Funda

  @conversion_timeout 60_000
  @max_pandoc_output_bytes 5 * 1024 * 1024

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
    content = File.read!(template_path)

    rendered =
      Enum.reduce(params, content, fn {k, v}, acc ->
        replace_content(k, v, acc)
      end)

    format = Map.get(params, "new_format") || "pdf"

    # Write to a temp file to avoid hardcoded paths and accidental overwrites.
    tmp_dir = System.tmp_dir!()
    rand = Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)
    updated_file_path = Path.join(tmp_dir, "wraft-rendered-#{rand}.md")

    File.write!(updated_file_path, rendered)
    Funda.convert(updated_file_path, format)
  end

  def replace_content(key, value, content) do
    String.replace(content, "[#{key}]", to_string(value))
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
        expanded = Path.expand(docx_path)

        with true <- File.exists?(expanded) or {:error, "Input file not found"},
             {:ok, %File.Stat{type: :regular}} <- File.stat(expanded) do
          port =
            Port.open({:spawn_executable, pandoc_path}, [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              # Use "--" before user-controlled paths to prevent option-injection.
              args: ["-f", "docx", "-t", "gfm", "--wrap=none", "--", expanded]
            ])

          receive_output(port, [], 0)
        else
          {:error, reason} -> {:error, to_string(reason)}
          {:ok, %File.Stat{type: other}} -> {:error, "Invalid input type: #{inspect(other)}"}
          other -> {:error, "Invalid input: #{inspect(other)}"}
        end
    end
  end

  defp receive_output(port, chunks, bytes) do
    receive do
      {^port, {:data, data}} ->
        new_bytes = bytes + byte_size(data)

        if new_bytes > @max_pandoc_output_bytes do
          Port.close(port)
          {:error, "Pandoc output exceeded #{@max_pandoc_output_bytes} bytes"}
        else
          receive_output(port, [data | chunks], new_bytes)
        end

      {^port, {:exit_status, 0}} ->
        {:ok, chunks |> Enum.reverse() |> IO.iodata_to_binary()}

      {^port, {:exit_status, status}} ->
        {:error, "Pandoc failed with exit code #{status}"}
    after
      @conversion_timeout ->
        Port.close(port)
        {:error, "Timeout waiting for Pandoc response"}
    end
  end
end
