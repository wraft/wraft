defmodule WraftDoc.Notification.NotitificationServer do
  @moduledoc """
  Asynchronously updates the notification
  """

  use GenServer
  require Logger
  alias WraftDoc.Notifications

  @doc """
  Starts the GenServer for Notification.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Asynchronously creates notifications for a list of users.
  """
  def create_notification(users, params) do
    GenServer.cast(__MODULE__, {:create_notification, users, params})
  end

  @doc """
  Asynchronously sends a comment notification.
  """
  def comment_notification(user_id, organisation_id, document_id) do
    GenServer.cast(__MODULE__, {:comment_notification, user_id, organisation_id, document_id})
  end

  @impl true
  def init(:ok) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:create_notification, users, params}, state) do
    case Notifications.create_notification(users, params) do
      {:ok, _result} ->
        Logger.debug("Notifications was sent to user")

      {:error, reason} ->
        Logger.error("Failed to send Notifications: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:comment_notification, user_id, organisation_id, document_id}, state) do
    case Notifications.comment_notification(user_id, organisation_id, document_id) do
      {:ok, _result} ->
        Logger.debug("Notifications was sent to user")

      {:error, reason} ->
        Logger.error("Failed to send Notifications: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:error, reason}, state) do
    Logger.error("Error in Notification: #{inspect(reason)}")
    {:noreply, state}
  end
end
