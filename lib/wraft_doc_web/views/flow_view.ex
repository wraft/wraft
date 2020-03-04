defmodule WraftDocWeb.Api.V1.FlowView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{UserView, StateView}

  def render("flow.json", %{flow: flow}) do
    %{
      id: flow.uuid,
      name: flow.name,
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

  def render("index.json", %{flows: flows}) do
    render_many(flows, __MODULE__, "update.json", as: :flow)
  end
end
