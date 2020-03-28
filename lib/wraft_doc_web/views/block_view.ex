defmodule WraftDocWeb.Api.V1.BlockView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("block.json", %{block: block}) do
    %{
      id: block.uuid,
      name: block.name,
      btype: block.btype,
      dataset: block.dataset,
      inserted_at: block.inserted_at,
      updated_at: block.updated_at
    }
  end
end
