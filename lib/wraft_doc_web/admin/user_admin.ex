defmodule WraftDocWeb.UserAdmin do
  import Ecto.Query
  alias WraftDocWeb.Router.Helpers, as: Routes

  def custom_links(_schema) do
    [
      %{
        name: "Logout",
        url: Routes.session_path(WraftDocWeb.Endpoint, :delete),
        method: :delete,
        order: 2,
        location: :top,
        icon: "user-circle"
      }
    ]
  end

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      email: %{name: "Email", value: fn x -> x.email end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      email: %{label: "Email"}
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:role])
  end
end
