# defmodule WraftDocWeb.ContentTypeChannel do
#   use WraftDocWeb, :channel
#   alias WraftDoc.Document.ContentType
#   alias WraftDoc.Repo

#   def join("content_type:list", payload, socket) do
#     if authorized?(payload) do
#       {:ok, socket}
#     else
#       {:error, %{reason: "unauthorized"}}
#     end
#   end

#   def handle_in("content_types", _payload, socket) do
#     content_types = ContentType |> Repo.all()

#     WraftDocWeb.Endpoint.broadcast!(socket.topic, "content_types", %{content_types: content_types})

#     {:noreply, socket}
#   end

#   def handle_in("insert", %{"content_type" => data}, socket) do
#     %ContentType{}
#     |> ContentType.changeset(data)
#     |> Repo.insert!()

#     {:noreply, socket}
#   end

#   def handle_in("update", %{"content_type" => data}, socket) do
#     ContentType
#     |> Repo.get(data["id"])
#     |> ContentType.changeset(data)
#     |> Repo.update!()

#     {:noreply, socket}
#   end

#   def handle_in("delete", %{"content_type" => data}, socket) do
#     ContentType
#     |> Repo.get(data["id"])
#     |> Repo.delete!()

#     {:noreply, socket}
#   end

#   defp authorized?(_payload) do
#     true
#   end
# end
