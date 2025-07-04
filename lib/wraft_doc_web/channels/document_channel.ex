defmodule WraftDocWeb.DocumentChannel do
  @moduledoc """
  Channel module for Document Collabaration
  """
  require Logger

  use Phoenix.Channel
  alias WraftDoc.Documents
  alias WraftDoc.SessionCache
  alias Yex.Sync.SharedDoc

  @impl true
  def join("doc_room:" <> content_id, _payload, socket) do
    case authorized?(content_id, socket.assigns.current_user) do
      true ->
        case start_shared_doc(content_id) do
          {:ok, docpid} ->
            Process.monitor(docpid)
            SharedDoc.observe(docpid)
            {:ok, assign(socket, content_id: content_id, doc_pid: docpid)}

          {:error, reason} ->
            {:error, %{reason: reason}}
        end

      {:error, reason} ->
        {:error, %{reason: reason}}
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

    case check_cached_access(cache_key) do
      {:ok, result} -> result
      :miss -> check_and_cache_access(content_id, current_user, cache_key)
    end
  end

  defp check_cached_access(cache_key) do
    case WraftDoc.SessionCache.get(cache_key) do
      {:ok, access} when is_boolean(access) ->
        {:ok, if(access, do: true, else: {:error, "Access denied"})}

      _ ->
        :miss
    end
  end

  defp check_and_cache_access(content_id, current_user, cache_key) do
    case WraftDoc.Documents.get_instance(content_id, current_user) do
      %WraftDoc.Documents.Instance{} = instance ->
        check_instance_access(instance, current_user, content_id, cache_key)

      {:error, reason} ->
        cache_access_denied(cache_key, reason)

      _ ->
        cache_access_denied(cache_key, "Access denied")
    end
  end

  defp check_instance_access(instance, current_user, content_id, cache_key) do
    has_access =
      cond do
        current_user.id in instance.allowed_users -> true
        Documents.has_access?(current_user, content_id) -> true
        Documents.has_access?(current_user, content_id, :counterparty) -> true
        true -> false
      end

    if has_access do
      SessionCache.put(cache_key, true, 15 * 60 * 1000)
      true
    else
      cache_access_denied(cache_key, "Access denied")
    end
  end

  defp cache_access_denied(cache_key, reason) do
    SessionCache.put(cache_key, false, 5 * 60 * 1000)
    {:error, reason}
  end
end
