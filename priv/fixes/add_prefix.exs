defmodule AddContentTypePrefixes do
  alias WraftDoc.{Document.ContentType, Repo}

  def get_all_content_types do
    ContentType
    |> Repo.all()
    |> Task.async_stream(fn x -> create_prefix_and_update_c_type(x) end)
    |> Enum.to_list()
  end

  def create_prefix_and_update_c_type(%{name: name} = c_type) do
    prefix =
      name
      |> String.split(" ")
      |> Enum.map(fn x -> String.slice(x, 0, 1) end)
      |> List.to_string()

    c_type |> ContentType.update_changeset(%{prefix: prefix}) |> Repo.update!()
  end
end

AddContentTypePrefixes.get_all_content_types()
