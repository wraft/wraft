defmodule WraftDocWeb.Api.V1.SearchController do
  @moduledoc """
  Handles search requests using the Typesense integration.
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Account.User
  alias WraftDoc.Search.Presets
  alias WraftDoc.Search.Typesense
  alias WraftDoc.Search.TypesenseServer

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      SearchResponse:
        swagger_schema do
          title("Search Results")
          description("Results returned from the search operation")

          properties do
            found(:integer, "Total number of results found")
            page(:integer, "Current page number")
            request_params(:object, "Parameters used in the search request")
          end

          example(%{
            hits: [
              %{
                document: %{
                  id: "124",
                  title: "Sample Document"
                },
                highlights: [
                  %{field: "title", snippet: "Sample <mark>Document</mark>"}
                ]
              }
            ],
            found: 1,
            page: 1,
            request_params: %{
              q: "sample",
              collection: "documents"
            }
          })
        end
    }
  end

  @doc """
    Search endpoint for querying collections.
  """
  swagger_path :search do
    get("/search")
    summary("Search collections")
    description("Search API for querying collections with various parameters")
    operation_id("search_collections")
    tag("Search")

    parameters do
      query(:query, :string, "Search query string", required: true)
      collection(:query, :string, "Collection name to search in")
      page(:query, :integer, "Page number for pagination", default: 1)
      per_page(:query, :integer, "Number of results per page", default: 10)
      sort_by(:query, :string, "Field to sort results by")
      sort_order(:query, :string, "Sort order (asc or desc)", enum: ["asc", "desc"])
      filter_by(:query, :string, "Filter expression")
      group_by(:query, :string, "Field to group results by")
      include_fields(:query, :string, "Comma-separated list of fields to include")
      exclude_fields(:query, :string, "Comma-separated list of fields to exclude")
    end

    response(200, "OK", Schema.ref(:SearchResponse))
    response(400, "Bad Request", Schema.ref(:Error))
    response(404, "Collection Not Found", Schema.ref(:Error))
  end

  @doc """
  Performs a search based on the provided query and collection, with options
  merged from default presets and request parameters.
  """
  @spec search(conn :: Plug.Conn.t(), params :: map()) :: Plug.Conn.t()
  def search(
        %{assigns: %{current_user: %{id: user_id, current_org_id: org_id}}} = conn,
        %{"query" => query, "collection_name" => collection} = params
      ) do
    org_filter = "organisation_id:=#{org_id}"

    opts =
      Presets.default_search_opts()
      |> Enum.map(fn {key, default} ->
        {key, Map.get(params, Atom.to_string(key), default)}
      end)
      |> Map.new()
      |> Map.put(:filter_by, org_filter)

    case Typesense.search(query, collection, opts) do
      {:ok, results} ->
        render(conn, "search.json",
          results: results,
          current_org_id: org_id,
          current_user_id: user_id,
          role_names: conn.assigns.current_user.role_names
        )

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  swagger_path :reindex do
    get("/reindex")
    summary("Typesense Reindex")
    description("Reindexing Data from Typesense")
    operation_id("reindexing")

    response(200, "Ok", Schema.ref(:SearchResponse))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @doc """
  Recreate collections and reindex them in Typesense .
  """
  @spec reindex(Plug.Conn.t(), map) :: Plug.Conn.t()
  def reindex(conn, _params) do
    %User{role_names: role_names} = conn.assigns.current_user

    if "superadmin" in role_names do
      TypesenseServer.initialize()
      json(conn, %{status: "success", message: "Collections initialized and data reindexed"})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Unauthorized access"})
      |> halt()
    end
  end
end
