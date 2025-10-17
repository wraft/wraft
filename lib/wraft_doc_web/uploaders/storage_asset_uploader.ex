defmodule WraftDocWeb.StorageAssetUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  alias WraftDoc.Client.Minio
  alias WraftDoc.Workers.PDFMetadataWorker

  @versions [:original]
  # 10MB limit
  @max_file_size 10 * 1024 * 1024

  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(
           ~w(.jpg .jpeg .png .pdf .doc .docx .xls .xlsx .ppt .pptx .txt .odt .csv),
           file_extension
         ) &&
           file_size(file) <= @max_file_size do
      true -> :ok
      false -> {:error, "invalid file type or size"}
    end
  end

  def filename(
        _version,
        {_file,
         %{
           storage_item: %{materialized_path: materialized_path}
         } = _scope}
      ) do
    materialized_path |> Path.basename() |> Path.rootname()
  end

  def storage_dir(
        _version,
        {_file,
         %{
           organisation_id: organisation_id,
           storage_item: %{materialized_path: materialized_path}
         } = _scope}
      ) do
    "organisations/#{organisation_id}/repository/#{String.replace(materialized_path, ~r{/[^/]*$}, "")}"
  end

  def default_url(_version, _scope), do: Minio.generate_url("public/images/default_asset.png")

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)

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
