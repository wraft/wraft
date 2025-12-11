defmodule WraftDocWeb.Api.V1.SearchController do
  @moduledoc """
  Handles search requests using the Typesense integration.
  """

  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Account.User
  alias WraftDoc.Search.Presets
  alias WraftDoc.Search.Typesense
  alias WraftDoc.Search.TypesenseServer
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Search, as: SearchSchema

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Search"])

  operation(:search,
    summary: "Search collections",
    description: "Search API for querying collections with various parameters",
    operation_id: "search_collections",
    parameters: [
      query: [in: :query, type: :string, description: "Search query string", required: true],
      collection: [in: :query, type: :string, description: "Collection name to search in"],
      page: [in: :query, type: :integer, description: "Page number for pagination (default: 1)"],
      per_page: [
        in: :query,
        type: :integer,
        description: "Number of results per page (default: 10)"
      ],
      sort_by: [in: :query, type: :string, description: "Field to sort results by"],
      sort_order: [in: :query, type: :string, description: "Sort order (asc or desc)"],
      filter_by: [in: :query, type: :string, description: "Filter expression"],
      group_by: [in: :query, type: :string, description: "Field to group results by"],
      include_fields: [
        in: :query,
        type: :string,
        description: "Comma-separated list of fields to include"
      ],
      exclude_fields: [
        in: :query,
        type: :string,
        description: "Comma-separated list of fields to exclude"
      ]
    ],
    responses: [
      ok: {"OK", "application/json", SearchSchema.SearchResponse},
      bad_request: {"Bad Request", "application/json", Error},
      not_found: {"Collection Not Found", "application/json", Error}
    ]
  )

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

  operation(:reindex,
    summary: "Typesense Reindex",
    description: "Reindexing Data from Typesense",
    operation_id: "reindexing",
    responses: [
      ok: {"Ok", "application/json", SearchSchema.ReindexResponse},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

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
