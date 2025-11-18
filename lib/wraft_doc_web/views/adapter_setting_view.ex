defmodule WraftDocWeb.Api.V1.AdapterSettingView do
  use WraftDocWeb, :view

  def render("index.json", %{adapters: adapters}) do
    %{
      adapters: adapters
    }
  end

  def render("show.json", %{adapter: adapter}) do
    adapter
  end
end
