defmodule ContentTypeCount do
  alias WraftDoc.{Repo, Document.ContentType, Document.Counter}

  def get_content_type_instances() do
    Repo.all(ContentType)
    |> Enum.each(fn x -> get_instances_and_udpate_count(x) end)
  end

  defp get_instances_and_udpate_count(c_type) do
    c_type = c_type |> Repo.preload(:instances)
    count = length(c_type.instances)

    Counter.changeset(%Counter{}, %{subject: "ContentType:" <> "#{c_type.id}", count: count})
    |> Repo.insert()
  end
end

ContentTypeCount.get_content_type_instances()
