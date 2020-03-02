defmodule WraftDocWeb.Api.V1.FlowView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("flow.json", %{flow: flow}) do
    %{
      id: flow.uuid,
      state: flow.state,
      order: flow.order
    }
  end

  def render("show.json", %{flow: flow}) do
    %{
      state: render_one(flow, FlowView, "flow.json", as: :flow),
      creator: render_one(flow.creator, UserView, "user.json", as: :user)
    }
  end

  def render("index.json", %{flows: flows}) do
    render_many(flows, __MODULE__, "show.json", as: :flow)
  end
end
