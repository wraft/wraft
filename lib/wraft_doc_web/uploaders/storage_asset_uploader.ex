defmodule WraftDocWeb.StorageAssetUploader do
  @moduledoc false
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original, :preview]

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

  def filename(:preview, {_file, %{storage_item: %{materialized_path: path}}}),
    do:
      path
      |> Path.basename()
      |> Path.rootname()
      |> then(&"#{&1}_preview")

  def filename(
        :original,
        {_file,
         %{
           storage_item: %{materialized_path: materialized_path}
         } = _scope}
      ) do
    materialized_path
    |> Path.basename()
    |> Path.rootname()
  end

  def storage_dir(
        :original,
        {_file,
         %{
           organisation_id: organisation_id,
           storage_item: %{materialized_path: materialized_path}
         } = _scope}
      ) do
    repo = Path.join(["organisations", organisation_id, "repository"])
    Path.join([repo, String.replace(materialized_path, ~r{/[^/]*$}, "")])
  end

  def storage_dir(
        :preview,
        {_file,
         %{
           organisation_id: organisation_id,
           storage_item: %{materialized_path: materialized_path}
         } = _scope}
      ) do
    repo = Path.join(["organisations", organisation_id, "repository_previews"])
    Path.join([repo, String.replace(materialized_path, ~r{/[^/]*$}, "")])
  end

  def transform(:preview, {file, _scope}) do
    ext = file.file_name |> Path.extname() |> String.downcase()

    cond do
      ext in ~w(.jpg .jpeg .png) ->
        {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}

      ext == ".pdf" ->
        {:convert,
         "-density 150 -flatten -thumbnail 250x250 -background white -alpha remove -format png",
         :png}

      true ->
        :noaction
    end
  end

  defp file_size(%Waffle.File{} = file), do: file.path |> File.stat!() |> Map.get(:size)
end
