defmodule WraftDocWeb.Api.V1.StateView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{UserView, FlowView}

  def render("create.json", %{state: state}) do
    %{
      id: state.uuid,
      state: state.state,
      order: state.order,
      updated_at: state.updated_at,
      inserted_at: state.inserted_at
    }
  end

  def render("show.json", %{state: state}) do
    %{
      state: render_one(state, StateView, "create.json", as: :state),
      flow: render_one(state.flow, FlowView, "flow.json", as: :flow),
      creator: render_one(state.creator, UserView, "user.json", as: :user)
    }
  end

  def render("index.json", %{states: states}) do
    render_many(states, __MODULE__, "show.json", as: :state)
  end
end
