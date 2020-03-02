defmodule WraftDocWeb.Api.V1.FlowView do
  use WraftDocWeb, :view

  def render("flow.json", %{flow: flow}) do
    %{
      id: flow.uuid,
      state: flow.state,
      order: flow.order
    }
  end
end
