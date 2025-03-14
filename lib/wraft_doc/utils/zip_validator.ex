defmodule WraftDoc.Utils.ZipValidator do
  @moduledoc """
  Helper functions to validate zip files.
  """

  @allowed_extensions [
    ".jpg",
    ".png",
    ".pdf",
    ".txt",
    ".jpeg",
    ".typ",
    ".typst",
    ".ttf",
    ".otf",
    ".tex",
    ".json",
    ".svg",
    ""
  ]
  @max_file_size 5_000_000
  @max_total_size 20_000_000

  @doc """
  Validate zip file.
  """
  @spec validate_zip(String.t()) :: {:ok, list()} | {:error, String.t()}
  def validate_zip(zip_path) do
    charlisted_path = to_charlist(zip_path)

    with {:ok, zip_info} <- :zip.list_dir(charlisted_path),
         {:ok, file_entries} <- extract_file_info(zip_info),
         :ok <- check_for_path_traversal(file_entries),
         :ok <- check_file_extensions(file_entries),
         :ok <- check_file_sizes(file_entries) do
      {:ok, file_entries}
    end
  end

  defp extract_file_info(zip_info) do
    file_entries =
      Enum.reduce(zip_info, [], fn
        {:zip_file, path, file_info, _, _, _}, acc ->
          [
            %{
              path: to_string(path),
              size: file_info_size(file_info),
              extension: path |> to_string() |> Path.extname() |> String.downcase()
            }
            | acc
          ]

        _other, acc ->
          acc
      end)

    {:ok, file_entries}
  end

  defp file_info_size({:file_info, size, _, _, _, _, _, _, _, _, _, _, _, _}), do: size

  defp check_for_path_traversal(file_entries) do
    if Enum.any?(file_entries, fn %{path: path} ->
         String.contains?(path, "../") || String.contains?(path, "..\\")
       end) do
      {:error, :path_traversal_attempt}
    else
      :ok
    end
  end

  defp check_file_extensions(file_entries) do
    invalid_files =
      Enum.filter(file_entries, fn %{extension: ext} ->
        ext not in @allowed_extensions
      end)

    if Enum.empty?(invalid_files) do
      :ok
    else
      invalid_exts = invalid_files |> Enum.map(& &1.extension) |> Enum.uniq()
      {:error, {:invalid_file_types, invalid_exts}}
    end
  end

  defp check_file_sizes(file_entries) do
    large_files =
      Enum.filter(file_entries, fn %{size: size} ->
        size > @max_file_size
      end)

    # Check total zip size
    total_size = Enum.reduce(file_entries, 0, fn %{size: size}, acc -> size + acc end)

    cond do
      not Enum.empty?(large_files) ->
        large_file_names = Enum.map(large_files, & &1.path)
        {:error, {:files_too_large, large_file_names}}

      total_size > @max_total_size ->
        {:error, {:total_size_too_large, total_size}}

      true ->
        :ok
    end
  end
end
