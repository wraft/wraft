defmodule WraftDocWeb.Api.V1.SearchView do
  use WraftDocWeb, :view
  alias WraftDoc.Search.Formatter

  def render("search.json", %{
        results: results,
        collection_name: collection_name,
        current_org_id: org_id,
        current_user_id: user_id
      }) do
    formatted_results =
      Formatter.format_results(results, org_id, user_id)

    %{
      collection_name => formatted_results
    }
  end
end
