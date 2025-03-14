defmodule WraftDoc.Utils.ZipHelper do
  @moduledoc """
    Helper functions to zip files.
  """

  alias WraftDoc.Frames.WraftJson
  alias WraftDoc.Utils.ZipValidator

  @required_files ["wraft.json", "template.typst", "default.typst"]

  @doc """
  Extract zip file into path.
  """
  @spec extract_zip(binary(), String.t()) :: String.t()
  def extract_zip(zip_binary, output_path) do
    {:ok, wraft_json} = get_wraft_json(zip_binary)

    wraft_json
    |> get_allowed_files_from_wraft()
    |> case do
      allowed_files ->
        Enum.each(allowed_files, fn allowed_file ->
          write_file(zip_binary, allowed_file, output_path)
        end)

        output_path
    end
  end

  defp write_file(zip_binary, allowed_file, output_path) do
    zip_binary
    |> extract_file_content(allowed_file)
    |> case do
      {:ok, file_content} ->
        file_path = Path.join(output_path, allowed_file)

        file_path
        |> Path.dirname()
        |> File.mkdir_p!()

        File.write!(file_path, file_content)

      _ ->
        nil
    end
  end

  @doc """
  Extract file content from zip file.
  """
  @spec extract_file_content(binary(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_file_content(zip_binary, file_name) do
    {:ok, unzip} = Unzip.new(zip_binary)
    unzip_stream = Unzip.file_stream!(unzip, file_name)

    file_content =
      unzip_stream
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
  Extract wraft_json from zip file.
  """
  @spec get_wraft_json(binary()) :: {:ok, map()}
  def get_wraft_json(zip_binary) do
    {:ok, wraft_json} = extract_file_content(zip_binary, "wraft.json")
    Jason.decode(wraft_json)
  end

  @doc """
    Read zip binary..
  """
  @spec read_zip_contents(String.t()) :: {:ok, binary()} | {:error, String.t()}
  def read_zip_contents(file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        {:ok, binary}

      _ ->
        {:error, "Invalid ZIP file."}
    end
  end

  @doc """
  Get zip entries.
  """
  @spec get_zip_entries(binary()) :: {:ok, list(map())} | {:error, String.t()}
  def get_zip_entries(zip_binary) do
    with {:ok, unzip} <- Unzip.new(zip_binary),
         entries <- Unzip.list_entries(unzip) do
      {:ok, entries}
    else
      _ ->
        {:error, "Invalid ZIP entries."}
    end
  end

  defp get_allowed_files_from_wraft(%{
         "packageContents" => %{"rootFiles" => root_files, "assets" => assets, "fonts" => fonts}
       }) do
    root_files = get_paths_from_section(root_files)
    assets = get_paths_from_section(assets)
    fonts = get_paths_from_section(fonts)

    root_files ++ assets ++ fonts ++ ["wraft.json"]
  end

  defp get_paths_from_section(section) when is_list(section) do
    Enum.map(section, fn item -> item["path"] end)
  end

  defp get_paths_from_section(_), do: []

  @doc """
  Validate frame zip.
  """
  @spec validate_frame_zip(String.t()) :: :ok | {:error, String.t()}
  def validate_frame_zip(file_path) do
    with {:ok, file_entries} <- ZipValidator.validate_zip(file_path),
         {:ok, _file_entries} <- validate_required_files(file_entries),
         {:ok, zip_binary} <- read_zip_contents(file_path),
         {:ok, wraft_json} <- get_wraft_json(zip_binary),
         :ok <- WraftJson.validate_json(wraft_json) do
      :ok
    else
      {:error, error} -> {:error, error}
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
end
