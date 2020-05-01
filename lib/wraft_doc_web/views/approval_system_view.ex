defmodule WraftDocWeb.Api.V1.ApprovalSystemView do
  use WraftDocWeb, :view

  def render("approval_system.json", %{approval_system: approval_system}) do
    %{
      instance: %{id: approval_system.instance.uuid},
      pre_state: %{id: approval_system.pre_state.uuid, state: approval_system.pre_state.state},
      post_state: %{id: approval_system.post_state.uuid, state: approval_system.post_state.state},
      approver: %{id: approval_system.approver.uuid, name: approval_system.approver.name},
      inserted_at: approval_system.inserted_at,
      updated_at: approval_system.updated_at
    }
  end

  def render("approve.json", %{approval_system: approval_system, instance: instance}) do
    %{
      instance: %{
        id: instance.uuid,
        state_id: instance.state.uuid,
        state: instance.state.state
      },
      pre_state: %{id: approval_system.pre_state.uuid, state: approval_system.pre_state.state},
      post_state: %{id: approval_system.post_state.uuid, state: approval_system.post_state.state},
      approved: approval_system.approved
    }
  end
end
