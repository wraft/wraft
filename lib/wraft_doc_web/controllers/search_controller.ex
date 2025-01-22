defmodule WraftDocWeb.Api.V1.SearchController do
  @moduledoc """
  Handles search requests using the Typesense integration.
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Search.Presets
  alias WraftDoc.Search.Typesense

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      SearchRequest:
        swagger_schema do
          title("Search Request")
          description("A search request to retrieve results from the application")

          properties do
            query(:string, "The search query", required: true)
            collection(:string, "The collection to search in")
            query_by(:string, "The fields to query by")
            filter_by(:string, "Filter criteria for the search")
            sort_by(:string, "Sorting criteria for the results")
            page(:integer, "The page number for pagination", required: false)
            per_page(:integer, "The number of results per page", required: false)
            prefix(:boolean, "Whether the query should use prefix matching", required: false)
          end

          example(%{
            query: "example",
            collection: "content_type",
            query_by: "name",
            filter_by: "status:active",
            sort_by: "created_at:desc",
            page: 1,
            per_page: 10,
            prefix: true
          })
        end,
      SearchResponse:
        swagger_schema do
          title("Search Response")
          description("The response from the search API")

          properties do
            data(:array, "The search results", items: Schema.ref(:SearchResult))
            total(:integer, "The total number of results")
            page(:integer, "The current page number")
            per_page(:integer, "The number of results per page")
          end

          example(%{
            data: [
              %{
                id: "1",
                name: "Sample Item 1",
                description: "This is a sample item."
              },
              %{
                id: "2",
                name: "Sample Item 2",
                description: "This is another sample item."
              }
            ],
            total: 25,
            page: 1,
            per_page: 10
          })
        end
    }
  end

  @doc """
    Search for documents in a collection.
  """
  swagger_path :search do
    get("/search")
    summary("Search API")
    description("Search API for querying collections")
    operation_id("search_documents")
    consumes("application/json")
    tag("Search")

    parameters do
      query(:query, :string, "Search query string", required: true)
      collection(:query, :string, "Collection to search in", required: false)
      query_by(:query, :string, "Fields to query by", required: false)
      filter_by(:query, :string, "Filter criteria for the search", required: false)
      sort_by(:query, :string, "Sorting criteria for the results", required: false)
      page(:query, :integer, "Page number for pagination", required: false)
      per_page(:query, :integer, "Number of results per page", required: false)
      prefix(:query, :boolean, "Use prefix matching", required: false)
    end

    response(200, "OK", Schema.ref(:SearchResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized for Access", Schema.ref(:Error))
  end

  @doc """
  Performs a search based on the provided query and collection, with options
  merged from default presets and request parameters.
  """
  def search(conn, params) do
    query = Map.get(params, "query", "")
    collection = Map.get(params, "collection")

    opts =
      Enum.reduce(Presets.default_search_opts(), %{}, fn {key, default_value}, acc ->
        param_value = Map.get(params, Atom.to_string(key))
        Map.put(acc, key, param_value || default_value)
      end)

    case Typesense.search(query, collection, opts) do
      {:ok, results} ->
        render(conn, "search.json", results: results)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end
end
