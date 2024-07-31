defmodule WraftDocWeb.Api.V1.InstanceApprovalController do
  @moduledoc """
  Controller module for Instance approval
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Document.Approval

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      ApprovalHistoryIndex:
        swagger_schema do
          example([
            %{
              approver: %{
                id: "ed94fb1b-ec43-4dfc-8a88-257d5547aa41",
                name: "John",
                profile_pic: "logo.png"
              },
              id: "016a9ade-6ffb-4ef2-b32e-af1c71bf7803",
              reviewed_at: "2024-03-22T13:11:48",
              status: "approved"
            }
          ])
        end
    }
  end

  @doc """
    Show approval history
  """
  swagger_path :approval_history do
    get("/contents/{id}/approval_history")
    summary("Show approval history")
    description("Show approval history")

    parameters do
      id(:path, :string, "Instance ID", required: true)
    end

    response(200, "Ok", Schema.ref(:ApprovalHistoryIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec approval_history(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def approval_history(conn, %{"id" => id}) do
    with {:ok, history} <- Approval.get_document_approval_history(id) do
      render(conn, "approval_history.json", history: history)
    end
  end
end
