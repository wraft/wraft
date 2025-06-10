defmodule WraftDocWeb.StorageAssetUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio
  alias WraftDoc.Workers.PDFMetadataWorker

  @versions [:original]
  @max_file_size 10 * 1024 * 1024  # 10MB limit

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(~w(.jpg .jpeg .png .pdf .doc .docx .xls .xlsx .ppt .pptx .txt .odt), file_extension) &&
         file_size(file) <= @max_file_size do
      true -> :ok
      false -> {:error, "invalid file type or size"}
    end
  end

  def filename(_version, {file, _}) do
    file.file_name
    |> Path.rootname()
    |> String.replace(~r/\s+/, "-")
  end

  def storage_dir(_version, {_file, %{organisation_id: organisation_id}}) do
    "organisations/#{organisation_id}/repo/assets"
  end

  def storage_dir(_version, _), do: "repositories"

  def default_url(_version, _scope), do: Minio.generate_url("public/images/default_asset.png")

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)

  # Add this new function to handle after_upload callback
  def after_upload({file, scope}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    if file_extension == ".pdf" do
      %{file_path: file.path, organisation_id: scope.organisation_id}
      |> PDFMetadataWorker.new()
      |> Oban.insert()
    end

    :ok
  end
end
