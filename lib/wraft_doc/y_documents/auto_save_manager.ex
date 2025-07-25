defmodule WraftDoc.YDocuments.AutoSaveManager do
  @moduledoc """
  Manages auto-save timers for collaborative documents.
  Handles multiple tabs and users properly with debounced saves.
  """

  use GenServer
  require Logger

  # 4 seconds when user stops typing
  @save_debounce_ms_idle 4_000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Notifies the manager about user activity.
  """
  def user_activity(content_id, user_id) do
    GenServer.cast(__MODULE__, {:user_activity, content_id, user_id})
  end

  @doc """
  Cancels auto-save for a specific user and document.
  """
  def cancel_auto_save(content_id, user_id) do
    GenServer.cast(__MODULE__, {:cancel_auto_save, content_id, user_id})
  end

  @impl GenServer
  def init(_) do
    {:ok, %{timers: %{}}}
  end

  @impl GenServer
  def handle_cast({:user_activity, content_id, user_id}, state) do
    user_key = {content_id, user_id}
    now = System.system_time(:millisecond)

    # Cancel existing timer for this user
    state = cancel_timer(state, user_key)

    # Schedule new timer
    timer_ref = Process.send_after(self(), {:save_after_idle, user_key}, @save_debounce_ms_idle)

    new_state =
      put_in(state.timers[user_key], %{
        timer_ref: timer_ref,
        last_activity: now
      })

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:cancel_auto_save, content_id, user_id}, state) do
    user_key = {content_id, user_id}
    new_state = cancel_timer(state, user_key)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:save_after_idle, user_key}, state) do
    {content_id, user_id} = user_key
    new_state = handle_save_timer(user_key, content_id, user_id, state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private function to cancel a timer
  defp cancel_timer(state, user_key) do
    case Map.get(state.timers, user_key) do
      %{timer_ref: timer_ref} ->
        Process.cancel_timer(timer_ref)
        %{state | timers: Map.delete(state.timers, user_key)}

      nil ->
        state
    end
  end

  # Handle save timer logic to reduce nesting
  defp handle_save_timer(user_key, content_id, user_id, state) do
    case Map.get(state.timers, user_key) do
      %{last_activity: last_activity} ->
        handle_active_timer(user_key, content_id, user_id, last_activity, state)

      nil ->
        # Timer was already cancelled
        %{state | timers: Map.delete(state.timers, user_key)}
    end
  end

  defp handle_active_timer(user_key, content_id, user_id, last_activity, state) do
    now = System.system_time(:millisecond)

    # Only save if user hasn't been active since the timer was set
    if now - last_activity >= @save_debounce_ms_idle do
      Logger.info("Auto-saving document #{content_id} for user #{user_id}")

      # Call the save function directly
      Task.start(fn ->
        try do
          WraftDoc.YDocuments.YEctoAdapter.save_document_state(content_id)
        rescue
          e ->
            Logger.error("Failed to auto-save document #{content_id}: #{inspect(e)}")
        end
      end)
    end

    # Remove the timer from state
    %{state | timers: Map.delete(state.timers, user_key)}
  end
end
