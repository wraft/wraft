defmodule WraftDocWeb.Api.V1.ActionController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
       [roles: [:creator], create_new: true]
       when action in [:index, :show, :update]

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Workflows.Actions.ActionSettings
  alias WraftDoc.Workflows.Actions.Registry
  alias WraftDoc.Workflows.AdapterSettings

  swagger_path :index do
    get("/actions")
    summary("List available actions")
    description("Returns list of all available workflow actions filtered by enabled adapters")

    response(200, "Success")
    response(401, "Unauthorized")
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    # Get enabled adapters for organization
    enabled_adapters = AdapterSettings.list_enabled_adapters(current_user.current_org_id)

    # Filter actions by enabled adapters
    actions = Registry.list_available_actions(enabled_adapters)

    # Get custom action settings for organization
    action_settings =
      WraftDoc.Workflows.Actions.ActionSettings.list_settings(current_user.current_org_id)

    settings_map = Enum.into(action_settings, %{}, fn s -> {s.action_id, s} end)

    # Merge actions with custom settings
    merged_actions =
      actions
      |> Enum.map(fn action ->
        action_id = Registry.get_action_id(action)
        setting = Map.get(settings_map, action_id)

        if setting do
          Map.merge(action, %{
            name: setting.name || action.name,
            description: setting.description || action.description,
            default_config: Map.merge(action.default_config, setting.default_config || %{}),
            is_active: setting.is_active
          })
        else
          Map.put(action, :is_active, true)
        end
      end)
      |> Enum.filter(& &1.is_active)

    # Group by category
    categories = Registry.list_categories()

    render(conn, "index.json", actions: merged_actions, categories: categories)
  end

  swagger_path :show do
    get("/actions/{id}")
    summary("Get action details")
    description("Returns action details including default configuration")

    parameters do
      id(:path, :string, "Action ID", required: true)
    end

    response(200, "Success")
    response(404, "Not found")
    response(401, "Unauthorized")
  end

  def show(conn, %{"id" => id}) do
    case Registry.get_action(id) do
      nil ->
        {:error, :not_found}

      action ->
        check_and_render_action(conn, action, id)
    end
  end

  defp check_and_render_action(conn, action, id) do
    current_user = conn.assigns.current_user
    enabled_adapters = AdapterSettings.list_enabled_adapters(current_user.current_org_id)

    if Enum.member?(enabled_adapters, action.adapter) do
      merged_action = build_merged_action(action, current_user.current_org_id, id)
      render(conn, "show.json", action: merged_action)
    else
      {:error, :forbidden}
    end
  end

  defp build_merged_action(action, org_id, id) do
    setting = ActionSettings.get_setting(org_id, id)

    if setting do
      Map.merge(action, %{
        name: setting.name || action.name,
        description: setting.description || action.description,
        default_config: Map.merge(action.default_config, setting.default_config || %{}),
        is_active: setting.is_active
      })
    else
      Map.put(action, :is_active, true)
    end
  end

  swagger_path :update do
    patch("/actions/{id}")
    summary("Update action setting")
    description("Update custom action configuration for organization")

    parameters do
      id(:path, :string, "Action ID", required: true)
      body(:body, Schema.ref(:ActionSettingRequest), "Action setting data", required: true)
    end

    response(200, "Success")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
    response(404, "Not found")
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    # Verify action exists
    case Registry.get_action(id) do
      nil ->
        {:error, :not_found}

      _action ->
        attrs = Map.take(params, ["name", "description", "default_config", "is_active"])

        case ActionSettings.upsert_action_setting(current_user, id, attrs) do
          {:ok, setting} ->
            # Get merged action
            action = Registry.get_action(id)

            merged_action =
              Map.merge(action, %{
                name: setting.name || action.name,
                description: setting.description || action.description,
                default_config: Map.merge(action.default_config, setting.default_config || %{}),
                is_active: setting.is_active
              })

            render(conn, "show.json", action: merged_action)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(WraftDocWeb.ErrorView)
            |> render("error.json", changeset: changeset)
        end
    end
  end
end
