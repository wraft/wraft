defmodule WraftDocWeb.Plug.Authorized do
  import Plug.Conn
  import Ecto.Query
  alias WraftDoc.{Repo, Account.Role, Authorization.Resource, Authorization.Permission}

  @category %{
    "WraftDocWeb.Api.V1.AssetController" => "Asset",
    "WraftDocWeb.Api.V1.BlockController" => "Block",
    "WraftDocWeb.Api.V1.ContentTypeController" => "Content type",
    "WraftDocWeb.Api.V1.DataTemplateController" => "Data template",
    "WraftDocWeb.Api.V1.EngineController" => "Engine",
    "WraftDocWeb.Api.V1.FlowController" => "Flow",
    "WraftDocWeb.Api.V1.InstanceController" => "Instance",
    "WraftDocWeb.Api.V1.LayoutController" => "Layout",
    "WraftDocWeb.Api.V1.ProfileController" => "Profile",
    "WraftDocWeb.Api.V1.StateController" => "State",
    "WraftDocWeb.Api.V1.ThemeController" => "Theme",
    "WraftDocWeb.Api.V1.UserController" => "User"
  }
  def init(_params) do
  end

  def call(conn, _params) do
    %{role: %{name: name}} = conn.assigns[:current_user]
    [_ | [category]] = conn.private[:phoenix_controller] |> to_string |> String.split("Elixir.")
    {_, category} = @category |> Enum.find(fn {k, _y} -> k == category end)
    action = conn.private[:phoenix_action] |> to_string

    from(p in Permission,
      join: r in Role,
      where: r.name == ^name,
      join: re in Resource,
      where: re.category == ^category and re.action == ^action,
      where: p.resource_id == re.id and p.role_id == r.id
    )
    |> Repo.one()
    |> case do
      %Permission{} ->
        conn

      nil ->
        body = Poison.encode!(%{error: "You are not authorized for this action.!"})

        send_resp(conn, 400, body)
        |> halt()
    end
  end
end
