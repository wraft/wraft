defmodule ContentTypeCount do
  alias WraftDoc.{Document.ContentType, Document.Counter, Repo}

  def get_content_type_instances do
    ContentType
    |> Repo.all()
    |> Enum.each(fn x -> get_instances_and_udpate_count(x) end)
  end

  defp get_instances_and_udpate_count(c_type) do
    c_type =  Repo.preload(c_type, :instances)
    count = length(c_type.instances)
    %Counter{}
    |> Counter.changeset(%{subject: "ContentType:" <> "#{c_type.id}", count: count})
    |> Repo.insert()
  end
end

ContentTypeCount.get_content_type_instances()
