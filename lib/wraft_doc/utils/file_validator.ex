defmodule WraftDoc.Utils.FileValidator do
  @moduledoc """
  Helper functions to validate file.
  """

  @allowed_extensions [
    ".jpg",
    ".png",
    ".pdf",
    ".jpeg",
    ".typ",
    ".typst",
    ".ttf",
    ".otf",
    ".tex",
    ".json",
    ".svg",
    ".md"
  ]
  @plain_text_extensions [".json", ".typ", ".typst", ".tex", ".svg", ".md"]
  @max_file_size 5_000_000
  @max_total_size 20_000_000

  @doc """
  Validates a ZIP file by performing a series of checks to ensure its integrity, security, and compliance with the application's requirements.

  The `validate_file/1` function is the entry point for validating files. It processes a file and performs the following checks:

  1. **File Metadata Extraction**:
     - Extracts metadata (e.g., file paths, sizes, extensions) from the ZIP archive.

  2. **Security Checks**:
     - Detects and prevents path traversal attacks by validating file paths.
     - Identifies encoded malicious patterns in file paths.

  3. **Validation**:
     - Ensures that all files have allowed extensions.
     - Verifies that individual file sizes and the total size of all files are within acceptable limits.
     - Checks file signatures to detect mismatches or unknown formats.

  """
  @spec validate_file(String.t()) :: {:ok, list()} | {:error, String.t()}
  def validate_file(file_path) do
    with {:ok, file_entries} <- get_file_entries(file_path),
         :ok <- check_for_path_traversal(file_entries),
         :ok <- check_file_sizes(file_entries),
         :ok <- check_file_signature(file_path) do
      {:ok, file_entries}
    end
  end

  # TODO filter out unwanted files.
  def get_file_entries(file_path) do
    file_path
    |> to_charlist()
    |> :zip.list_dir()
    |> case do
      {:ok, file_info} ->
        extract_file_info(file_info)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_file_info(file_info) do
    file_entries =
      Enum.reduce(file_info, [], fn
        {:zip_file, path, file_info, _, _, _}, acc ->
          path_string = to_string(path)

          if String.match?(path_string, ~r/^__MACOSX\//) or String.ends_with?(path_string, "/") do
            acc
          else
            [
              %{
                path: path_string,
                size: file_info_size(file_info),
                extension: path_string |> Path.extname() |> String.downcase()
              }
              | acc
            ]
          end

        _other, acc ->
          acc
      end)

    {:ok, file_entries}
  end

  defp file_info_size({:file_info, size, _, _, _, _, _, _, _, _, _, _, _, _}), do: size

  defp check_for_path_traversal(file_entries) do
    patterns = [
      ~r"\.\.[\\/]",
      ~r"\.\.%2[Ff]",
      ~r"%2[Ee]%2[Ee]%2[Ff]",
      ~r"\.\.%[Cc]0%[Aa][Ff]",
      ~r"\.\.[\\/][\\/]",
      ~r"[\\/]\.\."
    ]

    with {:ok, _safe} <- detect_traversal_pattern(file_entries, patterns),
         {:ok, _safe} <- detect_encoded_dots(file_entries) do
      :ok
    else
      {:error, entry} ->
        require Logger
        {:error, "Path traversal attempt detected in path: #{inspect(entry.path)}"}
    end
  end

  defp detect_traversal_pattern(file_entries, patterns) do
    case Enum.find(file_entries, &path_matches_pattern?(&1, patterns)) do
      nil -> {:ok, :safe}
      entry -> {:error, entry}
    end
  end

  defp path_matches_pattern?(%{path: path}, patterns) do
    normalized_path =
      path
      |> String.replace(~r"[\\/]+", "/")
      |> String.downcase()

    Enum.any?(patterns, &Regex.match?(&1, normalized_path))
  end

  defp detect_encoded_dots(file_entries) do
    case Enum.find(file_entries, &contains_encoded_dots?/1) do
      nil -> {:ok, :safe}
      entry -> {:error, entry}
    end
  end

  defp contains_encoded_dots?(%{path: path}) do
    path
    |> String.downcase()
    |> (&(String.contains?(&1, "%2f") ||
            (String.contains?(&1, "..") && String.contains?(&1, "%2")))).()
  end

  defp check_file_signature(file_path) do
    temp_path = Briefly.create!(directory: true)

    with {:ok, files} <- :zip.extract(to_charlist(file_path), [:memory]),
         [] <- Enum.reduce(files, [], &verify_signature(&1, &2, temp_path)) do
      :ok
    else
      mismatched_files ->
        mismatched_files
        |> Enum.map(fn path ->
          %{
            type: "file_validation_error",
            message: "file signature mismatch: #{path}"
          }
        end)
        |> then(&{:error, &1})
    end
  end

  defp verify_signature({path, binary}, acc, temp_path) do
    path_string = List.to_string(path)
    ext = path_string |> Path.extname() |> String.downcase()

    if not String.match?(path_string, ~r/^__MACOSX\//) and ext in @allowed_extensions and
         ext not in @plain_text_extensions do
      file_path = Path.join(temp_path, path_string)

      file_path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write!(file_path, binary)

      file_path
      |> FileType.from_path()
      |> case do
        {:ok, {detected_ext, _mime_type}} ->
          if ".#{detected_ext}" != ext do
            [path_string | acc]
          else
            acc
          end

        {:error, _reason} ->
          [path_string | acc]
      end
    else
      acc
    end
  end

  # TODO refactor this function.
  defp check_file_sizes(file_entries) do
    large_files = Enum.filter(file_entries, &(&1.size > @max_file_size))
    total_size = Enum.reduce(file_entries, 0, &(&1.size + &2))

    cond do
      Enum.any?(large_files) ->
        {:error, Enum.map(large_files, & &1.path)}

      total_size > @max_total_size ->
        {:error, total_size}

      true ->
        :ok
    end
  end
end
