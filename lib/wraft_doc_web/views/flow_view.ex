defmodule WraftDocWeb.Api.V1.FlowView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{UserView, StateView}

  def render("flow.json", %{flow: flow}) do
    %{
      id: flow.uuid,
      name: flow.name,
      controlled: flow.controlled,
      control_data: flow.control_data,
      updated_at: flow.updated_at,
      inserted_at: flow.inserted_at
    }
  end

  def render("update.json", %{flow: flow}) do
    %{
      flow: render_one(flow, FlowView, "flow.json", as: :flow),
      creator: render_one(flow.creator, UserView, "user.json", as: :user)
    }
  end

  def render("show.json", %{flow: flow}) do
    %{
      flow: render_one(flow, FlowView, "flow.json", as: :flow),
      creator: render_one(flow.creator, UserView, "user.json", as: :user),
      states: render_many(flow.states, StateView, "create.json", as: :state)
    }
  end

  def render("flow_and_states.json", %{flow: flow}) do
    %{
      flow: render_one(flow, FlowView, "flow.json", as: :flow),
      states: render_many(flow.states, StateView, "create.json", as: :state)
    }
  end

  def render("index.json", %{
        flows: flows,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      flows: render_many(flows, __MODULE__, "update.json", as: :flow),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
