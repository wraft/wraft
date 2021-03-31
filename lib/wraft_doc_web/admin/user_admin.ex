defmodule WraftDocWeb.UserAdmin do
  alias WraftDoc.Account.{User, Role}
  alias WraftDoc.Repo
  import Ecto.Query

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      email: %{name: "Email", value: fn x -> x.email end},
      role: %{name: "Role", value: fn x -> role_name(x) end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      email: %{label: "Email"},
      role: %{label: "Role", choices: Enum.map(roles(), fn x -> {x.name, x.id} end)}
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:role])
  end

  defp role_name(%User{role: %Role{name: role_name}}) do
    role_name
  end

  defp role_name(_), do: ""

  defp roles() do
    Role |> Repo.all()
  end
end
