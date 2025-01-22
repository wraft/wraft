defmodule WraftDoc.Search.Presets do
  @moduledoc """
  Defines default presets for search configurations.
  """

  def default_search_opts do
    %{
      query_by: "name",
      filter_by: nil,
      sort_by: nil,
      page: 1,
      per_page: 10,
      prefix: true
    }
  end
end
