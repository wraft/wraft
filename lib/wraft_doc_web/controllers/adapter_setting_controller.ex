defmodule WraftDocWeb.Api.V1.AdapterSettingController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
       [roles: [:creator], create_new: true]
       when action in [:index, :create, :update]

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Workflows.AdapterSetting
  alias WraftDoc.Workflows.AdapterSettings
  alias WraftDoc.Workflows.Adaptors.Registry

  swagger_path :index do
    get("/adapter_settings")
    summary("List adapter settings")
    description("Returns adapter settings for the current organization")

    response(200, "Success")
    response(401, "Unauthorized")
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    # Get all adapters
    all_adapters = Registry.list_adaptors()

    # Get settings for organization
    settings = AdapterSettings.list_settings(current_user.current_org_id)
    settings_map = Enum.into(settings, %{}, fn s -> {s.adapter_name, s} end)

    # Build adapter list with settings
    adapter_list =
      Enum.map(all_adapters, fn adapter_name ->
        setting = Map.get(settings_map, adapter_name)
        is_enabled_value = if setting, do: setting.is_enabled, else: true
        config_value = if setting, do: setting.config, else: %{}
        setting_id_value = if setting, do: setting.id, else: nil

        %{
          name: adapter_name,
          is_enabled: is_enabled_value,
          config: config_value,
          has_setting: not is_nil(setting),
          setting_id: setting_id_value
        }
      end)

    render(conn, "index.json", adapters: adapter_list)
  end

  swagger_path :create do
    post("/adapter_settings")
    summary("Enable/disable adapter")
    description("Create or update adapter setting")

    parameters do
      body(:body, Schema.ref(:AdapterSettingRequest), "Adapter setting data", required: true)
    end

    response(201, "Created")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
  end

  def create(conn, %{"adapter_name" => adapter_name, "is_enabled" => is_enabled} = params) do
    current_user = conn.assigns.current_user
    config = Map.get(params, "config", %{})

    result =
      if is_enabled do
        AdapterSettings.enable_adapter(current_user, adapter_name)
      else
        AdapterSettings.disable_adapter(current_user, adapter_name)
      end

    case result do
      {:ok, setting} ->
        # Update config if provided
        setting =
          if config != %{} do
            setting
            |> AdapterSetting.changeset(%{config: config})
            |> WraftDoc.Repo.update!()
          else
            setting
          end

        conn
        |> put_status(:created)
        |> render("show.json",
          adapter: %{
            name: setting.adapter_name,
            is_enabled: setting.is_enabled,
            config: setting.config,
            has_setting: true,
            setting_id: setting.id
          }
        )

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(WraftDocWeb.ErrorView)
        |> render("error.json", changeset: changeset)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "adapter_name and is_enabled are required"})
  end

  swagger_path :update do
    patch("/adapter_settings/:id")
    summary("Update adapter setting")
    description("Update adapter setting configuration")

    parameters do
      id(:path, :string, "Setting ID", required: true)
      body(:body, Schema.ref(:AdapterSettingRequest), "Adapter setting data", required: true)
    end

    response(200, "Success")
    response(422, "Unprocessable Entity")
    response(401, "Unauthorized")
    response(404, "Not found")
  end

  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    case WraftDoc.Repo.get(WraftDoc.Workflows.AdapterSetting, id) do
      nil ->
        {:error, :not_found}

      setting ->
        if setting.organisation_id != current_user.current_org_id do
          {:error, :forbidden}
        else
          update_setting(conn, setting, params)
        end
    end
  end

  defp update_setting(conn, setting, params) do
    attrs = Map.take(params, ["is_enabled", "config"])

    case setting
         |> WraftDoc.Workflows.AdapterSetting.changeset(attrs)
         |> WraftDoc.Repo.update() do
      {:ok, updated_setting} ->
        render(conn, "show.json",
          adapter: %{
            name: updated_setting.adapter_name,
            is_enabled: updated_setting.is_enabled,
            config: updated_setting.config,
            has_setting: true,
            setting_id: updated_setting.id
          }
        )

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(WraftDocWeb.ErrorView)
        |> render("error.json", changeset: changeset)
    end
  end

  def swagger_definitions do
    %{
      AdapterSettingRequest:
        swagger_schema do
          title("Adapter Setting Request")
          description("Request body for adapter settings")

          properties do
            adapter_name(:string, "Adapter name", required: true)
            is_enabled(:boolean, "Whether adapter is enabled", required: true)
            config(:map, "Adapter-specific configuration", required: false)
          end
        end
    }
  end
end
