defmodule WraftDocWeb.Api.V1.WorkflowWebhookController do
  @moduledoc """
  Controller for webhook-triggered workflow execution.

  Provides `POST /api/v1/workflows/:id/trigger` endpoint for triggering workflows via webhooks.
  Supports optional signature verification if a secret is configured.
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger

  require Logger

  alias WraftDoc.Workflows
  alias WraftDoc.Workflows.WorkflowRuns
  alias WraftDoc.Workflows.WorkflowTrigger

  action_fallback(WraftDocWeb.FallbackController)

  swagger_path :trigger do
    post("/workflows/{id}/trigger")
    summary("Trigger workflow via webhook")
    description("Execute a workflow using a webhook trigger with optional signature verification")

    parameters do
      id(:path, :string, "Workflow ID", required: true)
      body(:body, Schema.ref(:WebhookTriggerRequest), "Webhook payload", required: true)
    end

    response(200, "Success", Schema.ref(:WorkflowRun))
    response(404, "Workflow or trigger not found")
    response(403, "Invalid signature")
    response(422, "Unprocessable Entity")
  end

  def swagger_definitions do
    %{
      WebhookTriggerRequest:
        swagger_schema do
          title("Webhook Trigger Request")
          description("Request body for webhook trigger")

          properties do
            payload(:object, "Payload data to pass to workflow", required: false)
          end

          example(%{
            payload: %{
              event: "user.created",
              data: %{id: "123", name: "John"}
            }
          })
        end
    }
  end

  @doc """
  Trigger a workflow via webhook.

  Accepts POST requests with optional signature verification.
  """
  def trigger(conn, %{"id" => workflow_id} = params) do
    # Find active webhook trigger for this workflow
    case find_webhook_trigger(workflow_id) do
      nil ->
        Logger.warning(
          "[WorkflowWebhookController] No active webhook trigger found for workflow #{workflow_id}"
        )

        {:error, :not_found}

      trigger ->
        # Verify signature if secret is configured
        case verify_signature(conn, trigger, params) do
          :ok ->
            # Extract payload from request body
            payload = extract_payload(conn, params)

            # Execute workflow
            execute_workflow(conn, trigger, payload)

          {:error, reason} ->
            Logger.warning(
              "[WorkflowWebhookController] Signature verification failed: #{inspect(reason)}"
            )

            conn
            |> put_status(:forbidden)
            |> json(%{error: "Invalid signature"})
            |> halt()
        end
    end
  end

  defp find_webhook_trigger(workflow_id) do
    workflow = Workflows.get_workflow_for_trigger(workflow_id)

    if workflow do
      Enum.find(workflow.triggers, fn t -> t.type == "webhook" && t.is_active end)
    else
      nil
    end
  end

  defp verify_signature(_conn, %WorkflowTrigger{secret: nil}, _params), do: :ok

  defp verify_signature(conn, %WorkflowTrigger{secret: secret}, _params) when is_binary(secret) do
    # Simple HMAC-SHA256 signature verification
    # Format: X-Workflow-Signature: sha256=<signature>
    signature_header = conn |> get_req_header("x-workflow-signature") |> List.first()

    case signature_header do
      nil ->
        {:error, :missing_signature}

      "sha256=" <> received_signature ->
        # Get raw body
        raw_body = get_raw_body(conn)

        # Compute expected signature
        expected_signature =
          :hmac |> :crypto.mac(:sha256, secret, raw_body) |> Base.encode16(case: :lower)

        if Plug.Crypto.secure_compare(received_signature, expected_signature) do
          :ok
        else
          {:error, :invalid_signature}
        end

      _ ->
        {:error, :invalid_signature_format}
    end
  end

  defp get_raw_body(conn) do
    # Try to get raw body from conn.private (if cached by a plug)
    case Map.get(conn.private, :raw_body) do
      nil ->
        # Fallback: read from conn body (may be consumed)
        case conn.assigns[:raw_body] do
          nil -> ""
          body -> body
        end

      body ->
        body
    end
  end

  defp extract_payload(conn, params) do
    # Try to get payload from params first
    case Map.get(params, "payload") do
      nil ->
        # Try to parse JSON body
        case conn.body_params do
          %{} = body -> body
          _ -> %{}
        end

      payload ->
        payload
    end
  end

  defp execute_workflow(conn, trigger, payload) do
    # Create workflow run and execute
    # Use a system user context or anonymous execution
    # For now, we'll need to handle this without a user context
    # This is a limitation - webhooks may need organization context
    Logger.info(
      "[WorkflowWebhookController] Triggering workflow #{trigger.workflow_id} with payload"
    )

    # Note: This requires organization context - we may need to adjust this
    # For now, let's create a run directly
    case WorkflowRuns.create_and_execute_run_for_webhook(trigger, payload) do
      {:ok, run} ->
        run = WraftDoc.Repo.preload(run, run_jobs: :job, workflow: [:jobs, :edges])
        render(conn, "show.json", run: run)

      {:error, reason} ->
        Logger.error("[WorkflowWebhookController] Failed to execute workflow: #{inspect(reason)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end
end
