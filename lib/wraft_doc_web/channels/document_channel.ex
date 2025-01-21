defmodule WraftDocWeb.DocumentChannel do
  @moduledoc """
  Channel module for Document Collabaration
  """
  require Logger

  use Phoenix.Channel
  alias Yex.Sync.SharedDoc

  @impl true
  def join("doc_room:" <> content_id, payload, socket) do
    if authorized?(payload) do
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

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
