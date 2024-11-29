defmodule WraftDocWeb.FrameUploader do
  @moduledoc false

  use Waffle.Definition
  use Waffle.Ecto.Definition

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
      true -> :ok
      false -> {:error, "Invalid tex file."}
    end
  end

  def filename(_version, {file, _template}) do
    String.replace("frame_" <> Path.rootname(file.file_name, ".tex"), ~r/\s+/, "-")
  end

  def storage_dir(_version, {_file, scope}) do
    case scope.organisation_id do
      nil -> "public/frames"
      _ -> "organisations/#{scope.organisation_id}/frames/#{scope.id}"
    end
  end
end
