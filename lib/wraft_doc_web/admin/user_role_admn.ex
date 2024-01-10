defmodule WraftDocWeb.UserRoleAdmin do
  @moduledoc """
  Admin panel for user role
  """
  alias WraftDoc.{Account.Role, Account.User, Repo}
  import Ecto.Query

  def index(_) do
    [
      user_id: %{name: "User", value: fn x -> user_name(x) end},
      role_id: %{name: "Role", value: fn x -> role_name(x) end}
    ]
  end

  def form_fields(_) do
    [
      user_id: %{label: "User", choices: Enum.map(users(), fn x -> {x.name, x.id} end)},
      role_id: %{label: "Role", choices: Enum.map(roles(), fn x -> {x.name, x.id} end)}
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:user, :role])
  end

  defp user_name(%{user: %User{name: name}}) do
    name
  end

  defp user_name(_), do: ""

  defp role_name(%{role: %Role{name: name}}) do
    name
  end

  defp role_name(_), do: ""

  defp users do
    Repo.all(User)
  end

  defp roles do
    Repo.all(Role)
  end
end
