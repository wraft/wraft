defmodule WraftDocWeb.Api.V1.ApprovalSystemView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{FlowView, StateView, UserView}

  def render("approval_system.json", %{approval_system: approval_system}) do
    %{
      id: approval_system.id,
      name: approval_system.name,
      pre_state_id: approval_system.pre_state_id,
      post_state_id: approval_system.post_state_id,
      flow_id: approval_system.flow_id,
      approver_id: approval_system.approver_id
    }
  end

  def render("state_approval_system.json", %{approval_system: approval_system}) do
    %{
      approval_system:
        render_one(approval_system, __MODULE__, "approval_system.json", as: :approval_system),
      post_state: render_one(approval_system.post_state, StateView, "create.json", as: :state),
      approver: render_one(approval_system.approver, UserView, "user.json", as: :user)
    }
  end

  def render("show.json", %{approval_system: approval_system}) do
    %{
      approval_system:
        render_one(approval_system, __MODULE__, "approval_system.json", as: :approval_system),
      pre_state: render_one(approval_system.pre_state, StateView, "create.json", as: :state),
      post_state: render_one(approval_system.post_state, StateView, "create.json", as: :state),
      flow: render_one(approval_system.flow, FlowView, "flow.json", as: :flow),
      approver: render_one(approval_system.approver, UserView, "user.json", as: :user),
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
