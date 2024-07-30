defmodule WraftDocWeb.Api.V1.InstanceApprovalController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document.Approval
  

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
    Show form entry
  """
  swagger_path :approval_history do
    get("/contents/{id}/approval_history")
    summary("Show approval history")
    description("Show approval history")

    parameters do
      id(:path, :string, "Document ID", required: true)
    end

    response(200, "Ok", Schema.ref(:ApprovalHistoryIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def approval_history(conn, %{"id" => id}) do
    with {:ok, history} <- Approval.get_document_approval_history(id) do
      render(conn, "approval_history.json", history: history)
    else
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> render(WraftDocWeb.ErrorView, "404.json", reason: reason)
    end
  end

end