defmodule WraftDocWeb.Api.V1.RoleView do
  use WraftDocWeb, :view

  def render("role.json", %{role: role}) do
    %{
      id: role.uuid,
      name: role.name
    }
  end
end
