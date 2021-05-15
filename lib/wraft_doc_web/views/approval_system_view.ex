defmodule WraftDocWeb.Api.V1.ApprovalSystemView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("approval_system.json", %{approval_system: approval_system}) do
    %{
      instance: %{id: approval_system.instance.id},
      pre_state: %{id: approval_system.pre_state.id, state: approval_system.pre_state.state},
      post_state: %{id: approval_system.post_state.id, state: approval_system.post_state.state},
      approver: %{id: approval_system.approver.id, name: approval_system.approver.name},
      inserted_at: approval_system.inserted_at,
      updated_at: approval_system.updated_at
    }
  end

  def render("approve.json", %{approval_system: approval_system, instance: instance}) do
    %{
      instance: %{
        id: instance.id,
        state_id: instance.state.id,
        state: instance.state.state
      },
      pre_state: %{id: approval_system.pre_state.id, state: approval_system.pre_state.state},
      post_state: %{id: approval_system.post_state.id, state: approval_system.post_state.state},
      approved: approval_system.approved
    }
  end

  def render("error.json", %{message: message}) do
    %{
      status: false,
      message: message
    }
  end

  def render("pending_approvals.json", %{
        approval_systems: approval_systems,
        page_number: page_number,
        page_size: page_size,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      pending_approvals:
        render_many(approval_systems, ApprovalSystemView, "approval_system.json",
          as: :approval_system
        ),
      page_number: page_number,
      page_size: page_size,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
