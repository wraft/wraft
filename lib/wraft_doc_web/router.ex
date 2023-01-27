defmodule WraftDocWeb.Router do
  use WraftDocWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(WraftDocWeb.Guardian.AuthPipeline)
  end

  pipeline :valid_membership do
    plug(WraftDocWeb.Plug.ValidMembershipCheck)
  end

  pipeline :email_verify do
    plug(WraftDocWeb.Plug.VerifiedEmailCheck)
  end

  pipeline :ex_audit_track do
    plug(WraftDocWeb.Plug.ExAuditTrack)
  end

  pipeline :admin do
    plug(WraftDocWeb.Plug.AdminCheck)
  end

  pipeline :super_admin do
    plug(WraftDocWeb.Plug.SuperAdminCheck)
  end

  pipeline :admin_authenticate do
    plug(WraftDocWeb.Plug.AdminAuthenticate)
  end

  # pipeline :can do
  #   plug(WraftDocWeb.Plug.Authorized)
  # end

  scope "/", WraftDocWeb do
    # Use the default browser stack
    pipe_through(:browser)
    get("/", PageController, :index)
  end

  scope "/", WraftDocWeb do
    pipe_through(:browser)

    scope "/admin" do
      # Admin login
      get("/signin", SessionController, :new)
      get("/signup/new", SignupController, :new)
      post("/signin", SessionController, :create)
      post("/signup", SignupController, :create)
    end
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
      # Generate Email Verification Token
      post("/user/resend_email_token", UserController, :resend_email_token)
      # Verify Email Verification Token
      get("/user/verify_email_token/:token", UserController, :verify_email_token)
      # Show and index plans
      resources("/plans", PlanController, only: [:show, :index])
      post("/notifications", NotificationController, :create)
      # Verify Token
      get("/token", UserController, :token)
    end
  end

  # Scope which requires authorization.
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth, :valid_membership, :ex_audit_track, :email_verify])

    scope "/v1", Api.V1, as: :v1 do
      # Current user details
      get("/users/me", UserController, :me)
      # get user by there name
      get("/users/search", UserController, :search)
      get("/users/:id/instance-approval-systems", InstanceApprovalSystemController, :index)
      put("/users/:id/remove", UserController, :remove)

      get(
        "/users/instance-approval-systems",
        InstanceApprovalSystemController,
        :instances_to_approve
      )

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

      post("/content_type_roles", ContentTypeRoleController, :create)
      delete("/content_type_roles/:id", ContentTypeRoleController, :delete)

      resources("/roles", RoleController, only: [:create, :show, :delete])

      get("/content_types/:id/roles", ContentTypeController, :show_content_type_role)
      get("/content_types/title/search", ContentTypeController, :search)

      # Enginebody
      resources("/engines", EngineController, only: [:index])

      # Theme
      resources("/themes", ThemeController, only: [:create, :index, :show, :update, :delete])

      scope "/flows" do
        # Flows
        resources("/", FlowController, only: [:create, :index, :show, :update, :delete])
        # States
        resources("/:flow_id/states", StateController, only: [:create, :index])
        put("/:id/align-states", FlowController, :align_states)
      end

      # State delete and update
      resources("/states", StateController, only: [:update, :delete])

      # Data template show, delete and update
      resources("/data_templates", DataTemplateController, only: [:show, :update, :delete])

      # Instance show, update and delete
      resources("/contents", InstanceController, only: [:show, :update, :delete])
      # Instance state update
      patch("/contents/:id/states", InstanceController, :state_update)
      patch("/contents/:id/lock-unlock", InstanceController, :lock_unlock)
      get("/contents/title/search", InstanceController, :search)
      get("/contents/:id/change/:v_id", InstanceController, :change)
      # Approve a document
      put("/contents/:id/approve", InstanceController, :approve)
      put("/contents/:id/reject", InstanceController, :reject)
      # Organisations
      scope "/organisations" do
        resources("/", OrganisationController, only: [:create, :update, :show, :delete])
        get("/:id/members", OrganisationController, :members)
      end

      # collection form api
      get("/collection_forms/:id", CollectionFormController, :show)
      post("/collection_forms", CollectionFormController, :create)
      put("/collection_forms/:id", CollectionFormController, :update)
      delete("/collection_forms/:id", CollectionFormController, :delete)
      get("/collection_forms", CollectionFormController, :index)

      # collection form field api
      resources("/collection_forms/:c_form_id/collection_fields", CollectionFormFieldController,
        only: [:create, :update, :show, :delete, :index]
      )

      # Role group apis
      resources("/role_groups", RoleGroupController,
        only: [:create, :update, :show, :delete, :index]
      )

      # get("/collection_forms/:c_form_id/collection_fields/:id", CollectionFormFieldController, :show)
      # post("/collection_fields", CollectionFormFieldController, :create)
      # put("/collection_fields/:id", CollectionFormFieldController, :update)
      # delete("/collection_fields/:id", CollectionFormFieldController, :delete)

      resources("/vendors", VendorController, only: [:create, :update, :show, :index, :delete])
      # Update membership plan
      put("/memberships/:id", MembershipController, :update)
      # Get memberhsip
      get("/organisations/:id/memberships", MembershipController, :show)

      # Payments
      resources("/payments", PaymentController, only: [:index, :show])

      # Blocks
      resources("/blocks", BlockController, except: [:index])

      # Delete content type field
      resources("/content_type_fields", ContentTypeFieldController, only: [:delete])

      # Invite new user
      post("/organisations/users/invite", OrganisationController, :invite)

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
      resources("/approval_systems", ApprovalSystemController,
        only: [:create, :index, :show, :update, :delete]
      )

      resources("/organisation-fields", OrganisationFieldController, except: [:new, :edit])

      # post("/approval_systems/:id/approve", ApprovalSystemController, :approve)

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
    pipe_through([:api, :api_auth, :super_admin, :ex_audit_track, :email_verify])

    scope "/v1", Api.V1, as: :v1 do
      resources("/resources", ResourceController, only: [:create, :index, :show, :update, :delete])

      resources("/permissions", PermissionController, only: [:create, :index, :delete])

      resources("/field_types", FieldTypeController,
        only: [:create, :index, :show, :update, :delete]
      )

      # Create, Update and delete plans
      resources("/plans", PlanController, only: [:create, :update, :delete])

      # List all organisation details
      get("/organisations", OrganisationController, :index)
    end
  end

  use Kaffy.Routes, scope: "/admin", pipe_through: [:admin_authenticate]

  scope "/admin", WraftDocWeb do
    pipe_through([:kaffy_browser, :admin_authenticate])
    delete("/sign-out", SessionController, :delete)
  end

  # coveralls-ignore-start
  scope "/" do
    pipe_through([:browser, :api_auth, :admin])
    live_dashboard("/dashboard")
  end

  # coveralls-ignore-stop

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
