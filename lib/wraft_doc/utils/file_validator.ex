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
    ".svg"
  ]
  @plain_text_extensions [".json", ".typ", ".typst", ".tex", ".svg"]
  @max_file_size 5_000_000
  @max_total_size 20_000_000

  @doc """
  Validate file.
  """
  @spec validate_file(String.t()) :: {:ok, list()} | {:error, String.t()}
  def validate_file(file_path) do
    charlisted_path = to_charlist(file_path)

    with {:ok, file_info} <- :zip.list_dir(charlisted_path),
         {:ok, file_entries} <- extract_file_info(file_info),
         :ok <- check_for_path_traversal(file_entries),
         :ok <- check_file_sizes(file_entries),
         :ok <- check_file_extensions(file_entries),
         :ok <- check_file_signature(file_path) do
      {:ok, file_entries}
    end
  end

  defp extract_file_info(file_info) do
    file_entries =
      Enum.reduce(file_info, [], fn
        {:zip_file, path, file_info, _, _, _}, acc ->
          path_string = to_string(path)

          if String.ends_with?(path_string, "/") do
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

  defp check_file_extensions(file_entries) do
    invalid_files = Enum.filter(file_entries, &(&1.extension not in @allowed_extensions))

    if Enum.empty?(invalid_files) do
      :ok
    else
      invalid_exts = invalid_files |> Enum.map(& &1.extension) |> Enum.uniq()
      {:error, {:invalid_file_types, invalid_exts}}
    end
  end

  defp check_file_signature(file_path) do
    temp_path = Briefly.create!(directory: true)

    with {:ok, files} <- :zip.extract(to_charlist(file_path), [:memory]),
         [] <- Enum.reduce(files, [], &process_file(&1, &2, temp_path)) do
      :ok
    else
      mismatched_files when is_list(mismatched_files) ->
        {:error, format_mismatched_files(mismatched_files)}

      {:error, _reason} ->
        {:error, ""}
    end
  end

  defp process_file({path, binary}, acc, temp_path) do
    path_string = List.to_string(path)
    ext = path_string |> Path.extname() |> String.downcase()

    if ext in @allowed_extensions and ext not in @plain_text_extensions do
      file_path = Path.join(temp_path, path_string)
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, binary)

      case FileType.from_path(file_path) do
        {:ok, {detected_ext, _mime_type}} ->
          if ".#{detected_ext}" != ext do
            [{path_string, ext, detected_ext} | acc]
          else
            acc
          end

        {:error, _reason} ->
          [{path_string, ext, "unknown"} | acc]
      end
    else
      acc
    end
  end

  defp format_mismatched_files(mismatched_files) do
    Enum.map_join(mismatched_files, ", ", fn {path, ext, detected_ext} ->
      "#{path}: expected #{ext}, detected #{detected_ext}"
    end)
  end

  defp check_file_sizes(file_entries) do
    large_files = Enum.filter(file_entries, &(&1.size > @max_file_size))
    total_size = Enum.reduce(file_entries, 0, &(&1.size + &2))

    cond do
      Enum.any?(large_files) ->
        {:error, {:files_too_large, Enum.map(large_files, & &1.path)}}

      total_size > @max_total_size ->
        {:error, {:total_size_too_large, total_size}}

      true ->
        :ok
    end
  end
end
