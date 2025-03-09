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
  @spec format_results(
          search_results,
          org_id :: String.t(),
          user_id :: String.t(),
          role_names :: list()
        ) :: map()
  def format_results(results, org_id, user_id, role_names) do
    filtered_docs =
      results["hits"]
      |> apply_filters(org_id, user_id, role_names)
      |> format_documents()

    %{
      total: length(filtered_docs),
      documents: filtered_docs,
      page: results["page"]
    }
  end

  defp format_documents(hits) when is_list(hits) do
    Enum.map(hits, fn
      %{"document" => doc, "highlight" => %{"name" => %{"snippet" => highlight}}} ->
        doc
        |> Map.put("highlight", highlight)
        |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

      %{"document" => %{"collection_name" => "flow"} = doc, "highlight" => _highlight} ->
        doc
        # Default empty highlight
        |> Map.put("highlight", "")
        |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)

      %{"document" => doc, "highlight" => _highlight} ->
        doc
        |> Map.put("highlight", "")
        |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    end)
  end

  defp apply_filters(hits, org_id, user_id, role_names) do
    hits
    |> filter_by_org(org_id)
    |> filter_by_user_access(user_id, role_names)
  end

  defp filter_by_org(hits, org_id) do
    Enum.filter(hits, fn hit ->
      hit["document"]["organisation_id"] == org_id
    end)
  end

  defp filter_by_user_access(hits, _user_id, "superadmin"), do: hits

  defp filter_by_user_access(hits, user_id, _role_name) do
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
