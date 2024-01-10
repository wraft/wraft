defmodule WraftDocWeb.Api.V1.StateView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{ApprovalSystemView, FlowView, UserView}

  def render("create.json", %{state: state}) do
    %{
      id: state.id,
      state: state.state,
      order: state.order,
      updated_at: state.updated_at,
      inserted_at: state.inserted_at
    }
  end

  def render("instance_state.json", %{state: state}) do
    %{
      id: state.id,
      state: state.state,
      order: state.order,
      approval_system:
        render_one(state.approval_system, ApprovalSystemView, "state_approval_system.json",
          as: :approval_system
        )
    }
  end

  def render("state.json", %{state: state}) do
    %{
      id: state.id,
      state: state.state,
      order: state.order
    }
  end

  def render("show.json", %{state: state}) do
    %{
      state: render_one(state, StateView, "create.json", as: :state),
      flow: render_one(state.flow, FlowView, "flow.json", as: :flow),
      creator: render_one(state.creator, UserView, "user.json", as: :user)
    }
  end

  def render("index.json", %{
        states: states,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      states: render_many(states, __MODULE__, "show.json", as: :state),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
