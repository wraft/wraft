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
end
