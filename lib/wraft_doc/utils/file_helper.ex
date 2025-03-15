defmodule WraftDoc.Utils.FileHelper do
  @moduledoc """
    Helper functions to files.
  """

  alias WraftDoc.Frames.WraftJson
  alias WraftDoc.Utils.FileValidator

  @required_files ["wraft.json", "template.typst", "default.typst"]

  @doc """
  Extract file into path.
  """
  @spec extract_file(binary(), String.t()) :: String.t()
  def extract_file(file_binary, output_path) do
    {:ok, wraft_json} = get_wraft_json(file_binary)

    wraft_json
    |> get_allowed_files_from_wraft_json()
    |> case do
      allowed_files ->
        Enum.each(allowed_files, fn allowed_file ->
          write_file(file_binary, allowed_file, output_path)
        end)

        Path.join(output_path, ".")
    end
  end

  defp write_file(file_binary, allowed_file, output_path) do
    file_binary
    |> extract_file_content(allowed_file)
    |> case do
      {:ok, file_content} ->
        file_path = Path.join(output_path, allowed_file)

        file_path
        |> Path.dirname()
        |> File.mkdir()

        File.write!(file_path, file_content)

      _ ->
        nil
    end
  end

  @doc """
  Extract file content from file.
  """
  @spec extract_file_content(binary(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_file_content(file_binary, file_name) do
    {:ok, unfile} = Unzip.new(file_binary)
    unfile_stream = Unzip.file_stream!(unfile, file_name)

    file_content =
      unfile_stream
      |> Enum.into([], fn chunk -> chunk end)
      |> IO.iodata_to_binary()
      |> String.trim()

    case file_content do
      "" -> {:error, "File content is empty"}
      _ -> {:ok, file_content}
    end
  rescue
    e in Unzip.Error ->
      {:error, "Failed to extract file: #{Exception.message(e)}"}
  end

  @doc """
  Extract wraft_json from file.
  """
  @spec get_wraft_json(binary()) :: {:ok, map()}
  def get_wraft_json(file_binary) do
    {:ok, wraft_json} = extract_file_content(file_binary, "wraft.json")
    Jason.decode(wraft_json)
  end

  @doc """
    Read file binary..
  """
  @spec read_file_contents(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def read_file_contents(file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        {:ok, binary}

      _ ->
        {:error, "Invalid ZIP file."}
    end
  end

  @doc """
  Get file entries.
  """
  @spec get_file_entries(binary()) :: {:ok, list(map())} | {:error, String.t()}
  def get_file_entries(file_binary) do
    with {:ok, unfile} <- Unzip.new(file_binary),
         entries <- Unzip.list_entries(unfile) do
      {:ok, entries}
    else
      _ ->
        {:error, "Invalid ZIP entries."}
    end
  end

  defp get_allowed_files_from_wraft_json(%{
         "packageContents" => %{"rootFiles" => root_files, "assets" => assets, "fonts" => fonts}
       }) do
    [root_files, assets, fonts]
    |> Enum.map(&get_paths_from_section/1)
    |> List.flatten()
    |> then(&(&1 ++ ["wraft.json"]))
  end

  defp get_paths_from_section(section) when is_list(section) do
    Enum.map(section, fn item -> item["path"] end)
  end

  defp get_paths_from_section(_), do: []

  @doc """
  Validate frame.
  """
  @spec validate_frame_file(String.t()) :: :ok | {:error, String.t()}
  def validate_frame_file(file_path) do
    with {:ok, file_entries} <- FileValidator.validate_file(file_path),
         {:ok, _file_entries} <- validate_required_files(file_entries),
         {:ok, file_binary} <- read_file_contents(file_path),
         {:ok, wraft_json} <- get_wraft_json(file_binary),
         :ok <- WraftJson.validate_json(wraft_json),
         allowed_files <- get_allowed_files_from_wraft_json(wraft_json),
         {:ok, _} <- validate_missing_files(allowed_files, file_entries) do
      :ok
    end
  end

  defp validate_required_files(file_entries) do
    missing_files =
      Enum.filter(@required_files, fn req_file ->
        not Enum.any?(file_entries, fn entry -> entry.path == req_file end)
      end)

    if missing_files == [] do
      {:ok, file_entries}
    else
      {:error, "Required files are missing: #{Enum.join(missing_files, ",")}"}
    end
  end

  defp validate_missing_files(allowed_files, file_entries) do
    entry_paths = Enum.map(file_entries, &Map.get(&1, :path))

    missing_files =
      Enum.filter(allowed_files, fn allowed_file ->
        !Enum.any?(entry_paths, fn entry_path -> entry_path == allowed_file end)
      end)

    case missing_files do
      [] -> {:ok, file_entries}
      files -> {:error, "Files are missing in zip: #{Enum.join(files, ", ")}"}
    end
  end
end
