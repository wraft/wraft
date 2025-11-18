defmodule WraftDoc.Workflows.EventListener do
  @moduledoc """
  Event listener GenServer for PubSub events that trigger workflows.

  Listens for system events (e.g., document.created, document.signed) and
  executes matching workflows.
  """

  use GenServer

  require Logger
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.WorkflowRuns
  alias WraftDoc.Workflows.WorkflowTrigger

  import Ecto.Query

  @doc """
  Start the EventListener GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    # Subscribe to common events that can trigger workflows
    Phoenix.PubSub.subscribe(WraftDoc.PubSub, "workflow:document.created")
    Phoenix.PubSub.subscribe(WraftDoc.PubSub, "workflow:document.signed")
    Phoenix.PubSub.subscribe(WraftDoc.PubSub, "workflow:document.updated")

    Logger.info("[EventListener] Started listening for workflow events")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info({:phoenix, :broadcast, topic, _event, event_data}, state) do
    # Phoenix.PubSub sends messages as {:phoenix, :broadcast, topic, event, payload}
    # Extract event type from topic (e.g., "workflow:document.created" -> "document.created")
    event_type = String.replace_prefix(topic, "workflow:", "")
    handle_event(event_type, event_data)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    # Ignore other messages
    {:noreply, state}
  end

  @doc """
  Handle incoming events and trigger matching workflows.
  """
  def handle_event(event_type, event_data) do
    Logger.info("[EventListener] Received event: #{event_type}")

    # Find all active event triggers matching this event type
    triggers =
      WorkflowTrigger
      |> where([t], t.type == "event" and t.is_active == true)
      |> where([t], fragment("?->>'event_type' = ?", t.config, ^event_type))
      |> Repo.all()

    Logger.info("[EventListener] Found #{length(triggers)} matching triggers for #{event_type}")

    # Execute each matching workflow
    Enum.each(triggers, fn trigger ->
      execute_triggered_workflow(trigger, event_data)
    end)

    :ok
  end

  defp execute_triggered_workflow(
         %WorkflowTrigger{workflow_id: workflow_id} = trigger,
         event_data
       ) do
    Logger.info("[EventListener] Executing workflow #{workflow_id} for trigger #{trigger.id}")

    # Use event data as input to workflow
    input_data =
      Map.merge(
        Map.get(trigger.config, "input_data", %{}),
        %{"event_type" => extract_event_type(trigger), "event_data" => event_data}
      )

    case WorkflowRuns.create_and_execute_run_for_webhook(trigger, input_data) do
      {:ok, _run} ->
        Logger.info("[EventListener] Successfully triggered workflow #{workflow_id}")
        :ok

      {:error, reason} ->
        Logger.error(
          "[EventListener] Failed to trigger workflow #{workflow_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp extract_event_type(%WorkflowTrigger{config: config}) do
    Map.get(config, "event_type", "unknown")
  end
end
