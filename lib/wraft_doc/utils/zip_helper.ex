defmodule WraftDoc.Utils.ZipHelper do
  @moduledoc """
    Helper functions to zip files.
  """

  # TODO Check security.
  @doc """
  Extract zip file into path.
  """
  @spec extract_zip(binary(), String.t()) :: String.t() | {:error, String.t()}
  def extract_zip(zip_binary, output_path) do
    case :zip.extract(zip_binary, [{:cwd, output_path}]) do
      {:ok, _files} ->
        output_path

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extract wraft_json from zip file.
  """
  @spec get_wraft_json(binary()) :: {:ok, map()}
  def get_wraft_json(downloaded_zip_binary) do
    {:ok, wraft_json} = extract_file_content(downloaded_zip_binary, "wraft.json")
    Jason.decode(wraft_json)
  end

  @doc """
  Extract file content from zip file.
  """
  @spec extract_file_content(binary(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_file_content(zip_file_binary, file_name) do
    {:ok, unzip} = Unzip.new(zip_file_binary)
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
  end
end
