defmodule WraftDocWeb.DocumentChannel do
  @moduledoc """
  Channel module for Document Collabaration
  """
  require Logger

  use Phoenix.Channel
  alias WraftDoc.Documents
  alias Yex.Sync.SharedDoc

  @impl true
  def join("doc_room:" <> content_id, _payload, socket) do
    if authorized?(content_id, socket.assigns.current_user) do
      case start_shared_doc(content_id) do
        {:ok, docpid} ->
          Process.monitor(docpid)
          SharedDoc.observe(docpid)
          {:ok, assign(socket, content_id: content_id, doc_pid: docpid)}

        {:error, reason} ->
          {:error, %{reason: reason}}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("yjs_sync", {:binary, chunk}, socket) do
    SharedDoc.start_sync(socket.assigns.doc_pid, chunk)
    {:noreply, socket}
  end

  def handle_in("yjs", {:binary, chunk}, socket) do
    SharedDoc.send_yjs_message(socket.assigns.doc_pid, chunk)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:yjs, message, _proc}, socket) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, _pid, _reason},
        socket
      ) do
    {:stop, {:error, "remote process crash"}, socket}
  end

  def start_shared_doc(content_id) do
    result =
      case :global.whereis_name({__MODULE__, content_id}) do
        :undefined ->
          SharedDoc.start([doc_name: content_id, persistence: WraftDoc.EctoPersistence],
            name: {:global, {__MODULE__, content_id}}
          )

        pid ->
          {:ok, pid}
      end

    case result do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error("""
        Failed to start shareddoc.
        Room: #{inspect(content_id)}
        Reason: #{inspect(reason)}
        """)

        {:error, %{reason: "failed to start shareddoc"}}
    end
  end

  defp authorized?(content_id, current_user) do
    cache_key = {:doc_access, current_user.id, content_id}

    case WraftDoc.SessionCache.get(cache_key) do
      {:ok, access} when is_boolean(access) ->
        access

      _ ->
        access_result = Documents.has_access?(current_user, content_id)
        WraftDoc.SessionCache.put(cache_key, access_result, 15 * 60 * 1000)
        access_result
    end
  end
end
