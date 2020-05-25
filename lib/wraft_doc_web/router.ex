defmodule WraftDocWeb.Router do
  use WraftDocWeb, :router
  import Phoenix.LiveDashboard.Router

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

  # pipeline :can do
  # plug(WraftDocWeb.Plug.Authorized)
  # end

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
      resources("/users/signup/", RegistrationController, only: [:create])
      post("/users/signin", UserController, :signin)
      # to generate the auth token
      post("/user/password/forgot", UserController, :generate_token)
      # to verify the auth token and generate the jwt token
      get("/user/password/reset/:token", UserController, :verify_token)
      # Reset the password
      post("/user/password/reset", UserController, :reset)

      # Verify Token
      get("/token", UserController, :token)
    end
  end

  # Scope which requires authorization.
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth])

    scope "/v1", Api.V1, as: :v1 do
      # Current user details
      get("/users/me", UserController, :me)
      # Get activity stream for current user user
      get("/activities", UserController, :activity)
      # Update profile
      put("/profiles", ProfileController, :update)
      # Show current user's profile
      get("/profiles", ProfileController, :show_current_profile)
      # Update user password
      put("/user/password", UserController, :update_password)
      # Layout
      resources("/layouts", LayoutController, only: [:create, :index, :show, :update, :delete])
      # Delete layout asset
      delete("/layouts/:id/assets/:a_id", LayoutController, :delete_layout_asset)

      scope "/content_types" do
        # Content type
        resources("/", ContentTypeController, only: [:create, :index, :show, :update, :delete])

        scope "/:c_type_id" do
          # Bulk build
          post("/bulk_build", ContentTypeController, :bulk_build)
          # Instances
          resources("/contents", InstanceController, only: [:create, :index])

          # Data template
          resources("/data_templates", DataTemplateController, only: [:create, :index])
          post("/data_templates/bulk_import", DataTemplateController, :bulk_import)
        end
      end

      # Enginebody
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
      # Instance state update
      patch("/contents/:id/states", InstanceController, :state_update)

      # Organisations
      resources("/organisations", OrganisationController, only: [:create, :update, :show, :delete])

      resources("/blocks", BlockController, except: [:index])

      # Delete content type field
      resources("/content_type_fields", ContentTypeFieldController, only: [:delete])

      # Invite new user
      post("/organisations/:id/invite", OrganisationController, :invite)

      # All instances in an organisation
      get("/contents", InstanceController, :all_contents)

      # build PDF from a content
      post("/contents/:id/build", InstanceController, :build)

      # All data in an organisation
      get("/data_templates", DataTemplateController, :all_templates)
      # Block templates
      resources("/block_templates", BlockTemplateController)
      post("/block_templates/bulk_import", BlockTemplateController, :bulk_import)

      # Assets
      resources("/assets", AssetController)
      # Comments
      resources("/comments", CommentController)
      get("/comments/:id/replies", CommentController, :reply)
      # Approval system
      resources("/approval_systems", ApprovalSystemController)
      post("/approval_systems/approve", ApprovalSystemController, :approve)

      scope "/pipelines" do
        # Pipeline
        resources("/", PipelineController, only: [:create, :index, :show, :update, :delete])

        scope "/:pipeline_id" do
          # Trigger history
          resources("/triggers", TriggerHistoryController, only: [:create, :index])
          # Pipe stages
          resources("/stages", PipeStageController, only: [:create])
        end
      end

      # Update and Delete pipe stage
      resources("/stages", PipeStageController, only: [:update, :delete])
    end
  end

  # Scope which requires authorization.
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth, :admin])

    scope "/v1", Api.V1, as: :v1 do
      resources("/resources", ResourceController, only: [:create, :index, :show, :update, :delete])

      resources("/permissions", PermissionController, only: [:create, :index, :delete])

      resources("/field_types", FieldTypeController,
        only: [:create, :index, :show, :update, :delete]
      )
    end
  end

  scope "/" do
    pipe_through([:browser, :api_auth, :admin])
    live_dashboard("/dashboard")
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
      tags: [
        %{name: "Registration", description: "User registration"},
        %{name: "Organisation", description: "Manage Enterprise details"}
      ],
      security: [
        # ApiKey is applied to all operations
        %{
          Bearer: []
        }
      ]
    }
  end
end
