defmodule WraftDoc.DocConversion do
  @moduledoc false

  alias WraftDoc.Document.Asset
  alias WraftDoc.Document.Instance
  alias WraftDoc.Repo
  alias WraftDocWeb.Funda

  @doc """
  Converts a document from one format to another
  """
  def doc_conversion(template_path, params) do
    # "/Users/sk/offerletter.md"
    content = File.read!(template_path)
    a = Enum.reduce(params, content, fn {k, v}, acc -> replace_content(k, v, acc) end)
    updated_file_path = "/Users/sk/offerletter2.md"
    File.write(updated_file_path, a)
    Funda.convert(updated_file_path, params["new_format"])
  end

  def replace_content(key, value, content) do
    String.replace(content, "[#{key}]", value)
  end

  @doc """
    Refreshes the presigned URLs in the document for images
  """
  @spec refresh_presigned_urls(Instance.t()) :: Instance.t()
  def refresh_presigned_urls(
        %Instance{serialized: %{"serialized" => serialized} = serialized_map} = instance
      ) do
    # Temporarily for demo purpose ###########################
    # image = %{
    #   "type" => "image",
    #   "attrs" => %{
    #      "asset_id" => "1f0899ac-7cd7-4894-b140-ac1fe191fa72",
    #     "expiry_date" => "2024-01-01T00:00:00Z",
    #     "presigned_url" => "default"
    #   }
    # }

    # serialized =
    #   Map.update!(serialized |> Jason.decode!(), "content", fn content ->
    #     List.update_at(content, 0, fn paragraph ->
    #       Map.update!(paragraph, "content", fn paragraph_content ->
    #         paragraph_content ++ [image]
    #       end)
    #     end)
    #   end)
    # IO.inspect(serialized)
    #############################################################

    updated_serialized =
      serialized
      |> Jason.decode!()
      |> traverse_and_update()
      # |> IO.inspect(label: "updated serialized")
      |> Jason.encode!()

    %{instance | serialized: %{serialized_map | "serialized" => updated_serialized}}
  end

  defp traverse_and_update(
         %{
           "type" => "image",
           "attrs" => %{"expiry_date" => expiry_date, "asset_id" => asset_id} = _attrs
         } =
           image
       ) do
    if expired?(expiry_date) do
      new_url = generate_image_url(asset_id)

      put_in(image, ["attrs"], %{
        "presigned_url" => new_url,
        "expiry_date" => new_expiry_date(),
        "asset_id" => asset_id
      })
    else
      image
    end
  end

  defp traverse_and_update(%{"content" => content} = node) do
    updated_content = Enum.map(content, &traverse_and_update/1)
    %{node | "content" => updated_content}
  end

  defp traverse_and_update(other), do: other

  defp expired?(expiry_date) do
    with {:ok, datetime, _offset} <- DateTime.from_iso8601(expiry_date),
         do: DateTime.compare(datetime, DateTime.utc_now()) == :lt
  end

  def new_expiry_date do
    DateTime.utc_now()
    |> DateTime.add(5, :minute)
    |> DateTime.to_iso8601()
  end

  defp generate_image_url(asset_id) do
    %Asset{file: file} = asset = Repo.get(Asset, asset_id)
    WraftDocWeb.AssetUploader.url({file, asset}, signed: true)
  end
end
