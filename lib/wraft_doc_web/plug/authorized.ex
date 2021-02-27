defmodule WraftDocWeb.Plug.Authorized do
  @moduledoc false
  import Plug.Conn
  import Ecto.Query
  alias WraftDoc.{Authorization.Permission, Authorization.Resource, Repo}

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
    "WraftDocWeb.Api.V1.UserController" => "User",
    "WraftDocWeb.Api.V1.ContentTypeFieldController" => "ContentTypeField",
    "WraftDocWeb.Api.V1.ApprovalSystemController" => "ApprovalSystem",
    "WraftDocWeb.Api.V1.BlockTemplateController" => "BlockTemplate",
    "WraftDocWeb.Api.V1.CommentController" => "Comment",
    "WraftDocWeb.Api.V1.PipelineController" => "Pipeline",
    "WraftDocWeb.Api.V1.PipeStageController" => "Stage",
    "WraftDocWeb.Api.V1.TriggerHistoryController" => "TriggerHistory"
  }
  def init(_params) do
  end

  def call(conn, _params) do
    [_ | [category]] = conn.private[:phoenix_controller] |> to_string |> String.split("Elixir.")
    {_, category} = @category |> Enum.find(fn {k, _y} -> k == category end)
    action = conn.private[:phoenix_action] |> to_string

    from(r in Resource, where: r.category == ^category and r.action == ^action)
    |> Repo.one()
    |> check_permission(conn)
  end

  defp check_permission(%Resource{id: id}, conn) do
    %{role: %{id: role_id}} = conn.assigns[:current_user]

    from(p in Permission, where: p.resource_id == ^id and p.role_id == ^role_id)
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

  defp check_permission(nil, conn) do
    conn
  end
end
