defmodule WraftDoc.Search.Formatter do
  @moduledoc """
  Formats search results with organization and user access filtering
  """

  @type user_id :: String.t()
  @type org_id :: String.t()
  @type search_results :: map()

  @doc """
  Formats raw search results into structured data with filtering
  """
  @spec format_results(map(), org_id(), user_id()) :: search_results()
  def format_results(results, org_id, user_id) do
    filtered_docs =
      results["hits"]
      |> apply_filters(org_id, user_id)
      |> format_documents()

    %{
      found: length(filtered_docs),
      documents: filtered_docs,
      page: results["page"]
    }
  end

  @spec format_documents(list()) :: list(map())
  defp format_documents(hits) when is_list(hits) do
    Enum.map(hits, fn %{"document" => doc, "highlight" => %{"name" => %{"snippet" => highlight}}} ->
      doc
      |> Map.put("highlight", highlight)
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    end)
  end

  @spec apply_filters(list(), org_id(), user_id()) :: list()
  defp apply_filters(hits, org_id, user_id) do
    hits
    |> filter_by_org(org_id)
    |> filter_by_user_access(user_id)
  end

  @spec filter_by_org(list(), org_id()) :: list()
  defp filter_by_org(hits, org_id) do
    Enum.filter(hits, fn hit ->
      hit["document"]["organisation_id"] == org_id
    end)
  end

  @spec filter_by_user_access(list(), user_id()) :: list()
  defp filter_by_user_access(hits, user_id) do
    Enum.filter(hits, fn hit ->
      document = hit["document"]

      case Map.get(document, "allowed_users") do
        nil ->
          true

        allowed_users when is_list(allowed_users) ->
          Enum.member?(allowed_users, user_id)

        _ ->
          false
      end
    end)
  end
end
