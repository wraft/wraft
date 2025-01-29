defmodule WraftDocWeb.Api.V1.SearchView do
  use WraftDocWeb, :view

  def render("search.json", %{results: results}) do
    %{
      documents: extract_documents(results)
    }
  end

  defp extract_documents(%{"results" => results}) when is_list(results) do
    Enum.flat_map(results, fn
      %{"hits" => hits} when is_list(hits) ->
        Enum.map(hits, fn hit -> hit["document"] end)

      _ ->
        []
    end)
  end

  defp extract_documents(_), do: []
end
