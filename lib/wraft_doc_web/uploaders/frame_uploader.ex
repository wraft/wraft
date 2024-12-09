defmodule WraftDocWeb.FrameUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Document.Frame

  @versions [:original]
  @extension_whitelist ~w(.tex)

  def validate({file, _}) do
    file_extension =
      file.file_name
      |> Path.extname()
      |> String.downcase()

    @extension_whitelist
    |> Enum.member?(file_extension)
    |> case do
      true ->
        :ok

      false ->
        {:error, "Invalid tex file."}
    end
  end

  def filename(_version, {file, _template}) do
    String.replace("frame_" <> Path.rootname(file.file_name, ".tex"), ~r/\s+/, "-")
  end

  def storage_dir(_version, {_file, %Frame{id: id, organisation_id: organisation_id}}) do
    "organisations/#{organisation_id}/frames/#{id}"
  end
end
