defmodule WraftDocWeb.Api.V1.SearchView do
  use WraftDocWeb, :view
  alias WraftDoc.Search.Formatter

  def render("search.json", %{
        results: results,
        current_org_id: org_id,
        current_user_id: user_id,
        role_names: role_names
      }) do
    formatted_results =
      Formatter.format_results(results, org_id, user_id, role_names)

    formatted_results
  end
end
