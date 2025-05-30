defmodule WraftDocWeb.SignatureUploader do
  @moduledoc """
  This module provides a simple interface for uploading
  signature images for e-signatures
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  # Limit upload size to 1MB
  @max_file_size 1 * 1024 * 1024

  @versions [:original]
  @extension_whitelist ~w(.jpg .jpeg .png)

  # Validate File type and size
  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    case Enum.member?(@extension_whitelist, file_extension) && file_size(file) <= @max_file_size do
      true ->
        :ok

      false ->
        {:error, "Invalid file type or size. Supported formats: JPG, JPEG, PNG. Max size: 1MB"}
    end
  end

  # Change Filename to include timestamp for uniqueness
  def filename(_version, {_file, _counterparty}) do
    "signature"
  end

  # Storage Directory
  def storage_dir(_version, {_file, counterparty}) do
    "users/#{counterparty.user_id}/signatures"
  end

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
