defmodule WraftDocWeb.Api.V1.InstanceApprovalController do
  @moduledoc """
  Controller module for Instance approval
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Documents.Approval
  alias WraftDocWeb.Schemas

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Instance Approval"])

  @doc """
  Show approval history for a document instance
  """
  operation(:approval_history,
    summary: "Show approval history",
    description: "Retrieve the approval history for a specific document instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.InstanceApproval.ApprovalHistoryIndex},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  # TODO write test cases
  @spec approval_history(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def approval_history(conn, %{"id" => id}) do
    with {:ok, history} <- Approval.get_document_approval_history(id) do
      render(conn, "approval_history.json", history: history)
    end
  end
end
