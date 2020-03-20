defmodule WraftDocWeb.Router do
  use WraftDocWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(WraftDocWeb.Guardian.AuthPipeline)
  end

  pipeline :admin do
    plug(WraftDocWeb.Plug.AdminCheck)
  end

  pipeline :can do
    plug(WraftDocWeb.Plug.Authorized)
  end

  scope "/", WraftDocWeb do
    # Use the default browser stack
    pipe_through(:api)
    get("/", PageController, :index)
  end

  # Scope which does not need authorization.
  scope "/api", WraftDocWeb do
    pipe_through(:api)

    # user
    scope "/v1", Api.V1, as: :v1 do
      resources("/users/signup", RegistrationController, only: [:create])
      post("/users/signin", UserController, :signin)
    end
  end

  # Scope which requires authorization.
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth])

    scope "/v1", Api.V1, as: :v1 do
      # Current user details
      get("/users/me", UserController, :me)
      resources("/profile/:id", ProfileController, only: [:update])
      # Layout
      resources("/layouts", LayoutController, only: [:create, :index, :show, :update, :delete])

      scope "/content_types" do
        # Content type
        resources("/", ContentTypeController, only: [:create, :index, :show, :update, :delete])

        scope "/:c_type_id" do
          # Instances
          resources("/contents", InstanceController, only: [:create, :index])

          # Data template
          resources("/data_templates", DataTemplateController, only: [:create, :index])
        end
      end

      # Engine
      resources("/engines", EngineController, only: [:index])

      # Theme
      resources("/themes", ThemeController, only: [:create, :index, :show, :update, :delete])

      scope "/flows" do
        # Flows
        resources("/", FlowController, only: [:create, :index, :show, :update, :delete])
        # States
        resources("/:flow_id/states", StateController, only: [:create, :index])
      end

      # State delete and update
      resources("/states", StateController, only: [:update, :delete])

      # Data template show, delete and update
      resources("/data_templates", DataTemplateController, only: [:show, :update, :delete])

      # Instance show, update and delete
      resources("/contents", InstanceController, only: [:show, :update, :delete])

      # All instances in an organisation
      get("/contents", InstanceController, :all_contents)

      # uild PDF from a content
      post("/contents/:id/build", InstanceController, :build)

      # All instances in an organisation
      get("/data_templates", DataTemplateController, :all_templates)

      # Assets
      resources("/assets", AssetController, only: [:create, :index, :show, :update, :delete])
    end
  end

  # Scope which requires authorization.
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth, :admin])

    scope "/v1", Api.V1, as: :v1 do
      resources("/resources", ResourceController, only: [:create, :index, :show, :update, :delete])

      resources("/permissions", PermissionController, only: [:create, :index, :delete])
    end
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :wraft_doc, swagger_file: "swagger.json")
  end

  def swagger_info do
    %{
      info: %{
        version: "0.0.1",
        title: "Wraft Docs"
      },
      basePath: "/api/v1",
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header",
          description: "API Operations require a valid token."
        }
      },
      security: [
        # ApiKey is applied to all operations
        %{
          Bearer: []
        }
      ]
    }
  end
end
