defmodule WraftDocWeb.Api.V1.InstanceApprovalSystemController do
  @moduledoc """
  Controller module for Instance approval system
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Documents
  alias WraftDocWeb.Schemas

  tags(["Instance Approval System"])

  @doc """
  List all instance approval systems for a user
  """
  operation(:index,
    summary: "List all instance approval systems",
    description: "Retrieve a paginated list of all approval systems under a user",
    parameters: [
      id: [in: :path, type: :string, description: "User ID", required: true],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.InstanceApprovalSystem.InstanceApprovalSystemIndex},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      bad_request: {"Bad Request", "application/json", Schemas.Error}
    ]
  )

  def index(conn, %{"id" => user_id} = params) do
    with %{
           entries: instance_approval_systems,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.instance_approval_system_index(user_id, params) do
      render(conn, "index.json", %{
        instance_approval_systems: instance_approval_systems,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      })
    end
  end

  @doc """
  List all instances to approve for the current user
  """
  operation(:instances_to_approve,
    summary: "List all instance approval systems under current user",
    description: "Retrieve a paginated list of all approval systems for the current user",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.InstanceApprovalSystem.InstanceApprovalSystemIndex},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      bad_request: {"Bad Request", "application/json", Schemas.Error}
    ]
  )

  def instances_to_approve(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: instance_approval_systems,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.instance_approval_system_index(current_user, params) do
      render(conn, "index.json", %{
        instance_approval_systems: instance_approval_systems,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      })
    end
  end
end
