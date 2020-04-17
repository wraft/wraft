defmodule WraftDocWeb.Api.V1.BlockView do
  use WraftDocWeb, :view

  def render("block.json", %{block: block}) do
    %{
      id: block.uuid,
      name: block.name,
      btype: block.btype,
      dataset: block.dataset,
      file_url: block.file_url,
      api_route: block.api_route,
      endpoint: block.endpoint,
      inserted_at: block.inserted_at,
      updated_at: block.updated_at
    }
  end

  def render("create.json", %{block: block}) do
    %{
      id: block.uuid,
      name: block.name,
      btype: block.btype,
      dataset: block.dataset,
      file_url: block.file_url,
      api_route: block.api_route,
      endpoint: block.endpoint,
      inserted_at: block.inserted_at,
      updated_at: block.updated_at
    }
  end

  def render("update.json", %{block: block}) do
    %{
      id: block.uuid,
      name: block.name,
      btype: block.btype,
      dataset: block.dataset,
      file_url: block.file_url,
      api_route: block.api_route,
      endpoint: block.endpoint,
      inserted_at: block.inserted_at,
      updated_at: block.updated_at
    }
  end

  def render("show.json", %{block: block}) do
    %{
      id: block.uuid,
      name: block.name,
      btype: block.btype,
      dataset: block.dataset,
      file_url: block.file_url,
      api_route: block.api_route,
      endpoint: block.endpoint,
      inserted_at: block.inserted_at,
      updated_at: block.updated_at
    }
  end

  def render("error.json", %{message: message}) do
    %{
      status: false,
      message: message
    }
  end
end
