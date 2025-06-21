defmodule WraftDocWeb.Router do
  use WraftDocWeb, :router
  import Oban.Web.Router
  import Phoenix.LiveDashboard.Router

  alias WraftDoc.Enterprise

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

  pipeline :current_admin do
    plug(WraftDocWeb.Plug.CurrentAdmin)
  end

  pipeline :flags do
    plug(:accepts, ["html"])
    plug(:put_secure_browser_headers)
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(WraftDocWeb.Plug.CurrentAdmin)
  end

  pipeline :enterprise_plan_params do
    plug WraftDocWeb.Plugs.KaffyAdminPlug
  end

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
      post("/signin", SessionController, :create)
    end
  end

  # Separate scope with admin authentication
  scope "/", WraftDocWeb do
    pipe_through([:browser, :current_admin])
    oban_dashboard("/oban")
    live_dashboard("/dashboard")
  end

  scope "/", WraftDocWeb.Api.V1 do
    pipe_through(:api)
    # Asset image redirect to minio url
    get("/asset/image/:id", AssetController, :show_image)
  end

  # Scope which does not need authorization.
  scope "/api", WraftDocWeb do
    pipe_through(:api)

    # user
    scope "/v1", Api.V1, as: :v1 do
      resources("/users/signup/", RegistrationController, only: [:create])
      post("/users/signin", UserController, :signin)
      # Google Signin
      post("/users/signin/google", UserController, :signin_with_google)
      # Check email
      get("/users/check_email", UserController, :check_email)
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

      unless Enterprise.self_hosted?() do
        post("/vendors/webhook", VendorsWebhookController, :webhook)
        # Show and index plans
        get("/plans/active_plans", PlanController, :active_plans)
        resources("/plans", PlanController, only: [:show, :index])
      end

      # Verify access to a document instance
      get(
        "/guest/contents/:id/verify_access/:token",
        InstanceGuestController,
        :verify_document_access
      )

      # Verify invite token
      get(
        "/organisations/verify_invite_token/:token",
        OrganisationController,
        :verify_invite_token
      )

      # Invite token user status
      get(
        "/organisations/invite_token_status/:token",
        OrganisationController,
        :invite_token_status
      )

      # Refresh Token
      post("/users/token_refresh", UserController, :refresh_token)
      # Join Waiting list
      resources("/waiting_list", WaitingListController, only: [:create])
      # Set Password for first time
      post("/users/set_password", UserController, :set_password)

      # health
      get("/health", HealthController, :check_health)
    end

    # templates
    scope "/v1", Api.V1, as: :v1 do
      scope "/template_assets/public/templates" do
        get("/", TemplateAssetController, :list_public_templates)
        get("/:file_name/download", TemplateAssetController, :download_public_template)
      end
    end
  end

  # Scope which does not need authorization. (Guest User)
  # #TODO remove them because we are moving the guest user to be captured via token
  # scope "/api", WraftDocWeb do
  #   pipe_through([:api, :api_auth])

  #   # scope "/v1/guest", Api.V1, as: :v1 do
  #   #   resources("/contents", InstanceController, only: [:show, :update])
  #   #   resources("/comments", CommentController, only: [:create])
  #   # end
  # end

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
      # Dashboard Stats
      get("/dashboard_stats", DashboardController, :dashboard_stats)
      # Documents by content type
      get("/documents/by_content_type", DashboardController, :documents_by_content_type)
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

      resources("/roles", RoleController, only: [:create, :show, :delete, :index, :update])
      # Assign role
      post("/users/:user_id/roles/:role_id", RoleController, :assign_role)
      # Unassign role
      delete("/users/:user_id/roles/:role_id", RoleController, :unassign_role)

      get("/content_types/:id/roles", ContentTypeController, :show_content_type_role)
      get("/content_types/title/search", ContentTypeController, :search)

      # Enginebody
      resources("/engines", EngineController, only: [:index])
      resources("/frames", FrameController, only: [:index, :show, :create, :delete])

      scope "/forms" do
        # Forms
        resources("/", FormController, except: [:new, :edit])
        patch("/:id/status", FormController, :status_update)
        put("/:id/align-fields", FormController, :align_fields)
        # Entries
        resources("/:form_id/entries", FormEntryController, only: [:create, :show, :index])
      end

      scope "/forms/:form_id" do
        post("/mapping", FormMappingController, :create)
        get("/mapping/:mapping_id", FormMappingController, :show)
        put("/mapping/:mapping_id", FormMappingController, :update)
      end

      # Notification
      post("/notifications", NotificationController, :create)
      get("/notifications", NotificationController, :index)
      get("/notifications/count", NotificationController, :count)
      put("/notifications/read/:id", NotificationController, :read)
      put("/notifications/read_all", NotificationController, :read_all)

      # Theme
      resources("/themes", ThemeController, only: [:create, :index, :show, :update, :delete])

      scope "/flows" do
        # Flows
        resources("/", FlowController, only: [:create, :index, :show, :update, :delete])
        # States
        put("/:id/align-states", FlowController, :align_states)
        resources("/:flow_id/states", StateController, only: [:create, :index])
      end

      # State delete and update
      resources("/states", StateController, only: [:update, :delete])

      # Add, remove or list user to state at document level
      post("/states/:state_id/users/:user_id", StateController, :add_user_to_state)
      delete("/states/:state_id/users/:user_id", StateController, :remove_user_from_state)
      get("/states/:state_id/users", StateController, :list_users_in_state)

      # Data template show, delete and update
      resources("/data_templates", DataTemplateController, only: [:show, :update, :delete])

      # Instance show, update and delete
      resources("/contents", InstanceController, only: [:show, :update, :delete])
      # Instance meta update
      put("/contents/:id/meta", InstanceController, :update_meta)
      # Instance state update
      patch("/contents/:id/states", InstanceController, :state_update)
      patch("/contents/:id/lock-unlock", InstanceController, :lock_unlock)
      get("/contents/title/search", InstanceController, :search)
      get("/contents/:id/change/:v_id", InstanceController, :change)

      # Contract chart
      get("/contracts/chart", InstanceController, :contract_chart)

      # Share an instance
      post("/contents/:id/invite", InstanceGuestController, :invite)
      # Revoke document access
      patch(
        "/contents/:id/revoke_access/:collaborator_id",
        InstanceGuestController,
        :revoke_document_access
      )

      # List collaborators
      get("/contents/:id/collaborators", InstanceGuestController, :list_collaborators)
      # Update role for a collaborator
      patch(
        "/contents/:id/collaborators/:collaborator_id",
        InstanceGuestController,
        :update_collaborator_role
      )

      # Delete counterpart
      delete(
        "/contents/:id/remove_counterparty/:counterparty_id",
        InstanceGuestController,
        :remove_counterpart
      )

      # Document reminders
      scope "/contents/:content_id" do
        resources("/reminders", ReminderController, except: [:index])
      end

      # List all reminders
      get("/reminders", ReminderController, :index)

      # Approve a document
      put("/contents/:id/approve", InstanceController, :approve)
      put("/contents/:id/reject", InstanceController, :reject)
      # get Approval history
      get("/contents/:id/approval_history", InstanceApprovalController, :approval_history)
      # Send document instance email
      post("/contents/:id/email", InstanceController, :send_email)
      # Import docx
      post("/import_docx", DocumentController, :import_docx)

      get("/users/list_pending_approvals", InstanceController, :list_pending_approvals)

      # Organisations
      scope "/organisations" do
        # Feature flags routes (must come before generic :id routes)
        get("/features", FeatureFlagController, :index)
        get("/features/:feature", FeatureFlagController, :show)
        put("/features/:feature", FeatureFlagController, :update)
        put("/features", FeatureFlagController, :bulk_update)

        resources("/", OrganisationController, only: [:create, :update, :show])
        delete("/", OrganisationController, :delete)
        post("/request_deletion", OrganisationController, :request_deletion)
        get("/:id/members", OrganisationController, :members)
        # Invite new user
        post("/users/invite", OrganisationController, :invite)
        # Removes existing user
        post("/remove_user/:id", OrganisationController, :remove_user)
        # permissions of user in organisation
        get("/users/permissions", OrganisationController, :permissions)
        # Transfer ownership
        post("/transfer_ownership", OrganisationController, :transfer_ownership)
      end

      # List Organisation by User
      get("/users/organisations", UserController, :index_by_user)
      # Switch organisation
      post("/switch_organisations", UserController, :switch_organisation)
      # Join organisation
      post("/join_organisation", UserController, :join_organisation)
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

      if !Enterprise.self_hosted?() do
        # Billing
        scope "/billing/subscription" do
          get("/", BillingController, :get_subscription)
          get("/active", BillingController, :get_active_subscription)
          post("/:plan_id/change/preview", BillingController, :change_plan_preview)
          post("/:plan_id/change", BillingController, :change_plan)
          patch("/activate_trial", BillingController, :activate_trial_subscription)
          get("/:transaction_id/invoice", BillingController, :get_invoice)
          get("/:organisation_id/transactions", BillingController, :get_transactions)
          get("/:organisation_id/history", BillingController, :subscription_history_index)
          delete("/cancel", BillingController, :cancel_subscription)
        end

        # Update membership plan
        put("/memberships/:id", MembershipController, :update)
        # Get memberhsip
        get("/organisations/:id/memberships", MembershipController, :show)

        # Payments
        resources("/payments", PaymentController, only: [:index, :show])
      end

      # Blocks
      resources("/blocks", BlockController, except: [:index])

      # Delete content type field
      delete(
        "/content_type/:content_type_id/field/:field_id",
        ContentTypeFieldController,
        :delete
      )

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

      post("/global_asset/pre_import", GlobalImportController, :pre_import_global_file)
      post("/global_asset/re_validate", GlobalImportController, :re_validate_global_file)
      post("/global_asset/import", GlobalImportController, :import_global_file)

      # Template Assets
      resources("/template_assets", TemplateAssetController)
      post("/template_assets/:id/import", TemplateAssetController, :template_import)

      post(
        "/template_assets/public/:id/install",
        TemplateAssetController,
        :import_public_template
      )

      post("/template_assets/:id/export", TemplateAssetController, :template_export)
      get("/template_assets/:id/pre_import", TemplateAssetController, :template_pre_import)

      # Comments
      resources("/comments", CommentController)
      get("/comments/:id/replies", CommentController, :reply)
      # Approval system
      resources("/approval_systems", ApprovalSystemController,
        only: [:create, :index, :show, :update, :delete]
      )

      resources("/organisation-fields", OrganisationFieldController, except: [:new, :edit])

      # Search
      get("/search", SearchController, :search)
      get("/reindex", SearchController, :reindex)

      # post("/approval_systems/:id/approve", ApprovalSystemController, :approve)

      scope "/pipelines" do
        # Pipeline
        resources("/", PipelineController, only: [:create, :index, :show, :update, :delete])

        scope "/:pipeline_id" do
          # Trigger history
          resources("/triggers", TriggerHistoryController, only: [:create])
          get("/triggers", TriggerHistoryController, :index_by_pipeline)
          # Pipe stages
          resources("/stages", PipeStageController, only: [:create])
        end
      end

      get("/triggers", TriggerHistoryController, :index)

      # Update and Delete pipe stage
      resources("/stages", PipeStageController, only: [:update, :delete])

      resources("/permissions", PermissionController, only: [:index])
      get("/resources", PermissionController, :resource_index)

      resources(
        "/field_types",
        FieldTypeController,
        only: [:create, :index, :show, :update, :delete]
      )

      # Signature routes
      post("/contents/:id/add_counterparty", SignatureController, :add_counterparty)
      post("/contents/:id/signatures", SignatureController, :create_signature)
      get("/contents/:id/signatures/:signature_id", SignatureController, :get_signature)
      get("/contents/:id/counterparties", SignatureController, :list_counterparties)
      post("/contents/:id/request_signature", SignatureController, :request_signature)
      get("/contents/:id/signatures", SignatureController, :get_document_signatures)
      delete("/contents/:id/signatures/:counter_party_id", SignatureController, :revoke_signature)
      # Temporary route
      post("/contents/:id/generate_signature", SignatureController, :generate_signature)
      put("/contents/:id/signatures/:signature_id", SignatureController, :update_signature)

      post("/contents/:id/append_signature", SignatureController, :apply_visual_signature)

      post(
        "/contents/:id/signatures/:signature_id/assign",
        SignatureController,
        :assign_counter_party
      )

      # AI/ML Management
      scope "/ai" do
        resources("/models", ModelController, except: [:new, :edit])
        resources("/prompts", PromptsController, except: [:new, :edit])
        post("/generate", AiToolController, :execute)
      end
    end
  end

  # Scope which requires authorization.
  # TODO Decide what all checks we need for these APIs
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth, :ex_audit_track, :email_verify])

    scope "/v1", Api.V1, as: :v1 do
      # List all organisation details
      get("/organisations", OrganisationController, :index)
    end
  end

  if Enterprise.self_hosted?() do
    use Kaffy.Routes, scope: "/admin", pipe_through: [:current_admin]
  else
    use Kaffy.Routes, scope: "/admin", pipe_through: [:current_admin, :enterprise_plan_params]
  end

  scope "/admin", WraftDocWeb do
    pipe_through([:kaffy_browser, :current_admin])
    delete("/sign-out", SessionController, :delete)
  end

  scope path: "/flags" do
    pipe_through(:flags)
    forward("/", FunWithFlags.UI.Router, namespace: "flags")
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
