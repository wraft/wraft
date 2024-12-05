defmodule WraftDocWeb.Api.V1.SearchController do
  use WraftDocWeb, :controller

  action_fallback(WraftDocWeb.FallbackController)

  def search(conn, params) do
    query = Map.get(params, "query", "")
    collection = Map.get(params, "collection")

    opts = [
      query_by: Map.get(params, "query_by") || "name",
      filter_by: Map.get(params, "filter_by") || nil,
      sort_by: Map.get(params, "sort_by") || nil,
      page: Map.get(params, "page") || 1,
      per_page: Map.get(params, "per_page") || 10,
      prefix: Map.get(params, "prefix") || true
    ]

    {:ok, results} = WraftDoc.Search.Typesense.search(query, collection, opts)

    render(conn, "search.json", results: results)
  end
end
