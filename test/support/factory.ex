defmodule WraftDoc.Factory do
  @moduledoc """
  Factory for creating test data. Used by ExMachina.
  """
  use ExMachina.Ecto, repo: WraftDoc.Repo

  alias WraftDoc.Account.Activity
  alias WraftDoc.Account.Country
  alias WraftDoc.Account.Profile
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.RoleGroup
  alias WraftDoc.Account.User
  alias WraftDoc.Account.User.Audience
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Account.UserRole
  alias WraftDoc.ApiKeys.ApiKey
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Authorization.Permission
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Blocks.Block
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.CollectionForms.CollectionForm
  alias WraftDoc.CollectionForms.CollectionFormField
  alias WraftDoc.Comments.Comment
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDoc.ContentTypes.ContentTypeRole
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents.ContentCollaboration
  alias WraftDoc.Documents.Counter
  alias WraftDoc.Documents.Engine
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Instance.History
  alias WraftDoc.Documents.Instance.Version
  alias WraftDoc.Documents.InstanceApprovalSystem
  alias WraftDoc.Documents.OrganisationField
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Membership
  alias WraftDoc.Enterprise.Membership.Payment
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.StateUser
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Forms.Form
  alias WraftDoc.Forms.FormEntry
  alias WraftDoc.Forms.FormField
  alias WraftDoc.Forms.FormMapping
  alias WraftDoc.Forms.FormPipeline
  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.Stages.Stage
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset
  alias WraftDoc.WaitingLists.WaitingList

  def user_factory do
    %User{
      name: "wrafts user",
      email: "#{Base.encode16(:crypto.strong_rand_bytes(10), case: :lower)}@wmail.com",
      email_verify: true,
      password: "encrypt",
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      current_org_id: nil,
      owned_organisations: [],
      is_guest: false
    }
  end

  def user_with_personal_organisation_factory do
    unique_email = "#{Base.encode16(:crypto.strong_rand_bytes(10), case: :lower)}@wmail.com"
    organisation = insert(:organisation, name: "Personal", email: unique_email)

    %User{
      name: "wrafts user",
      email: unique_email,
      email_verify: true,
      password: "encrypt",
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      current_org_id: organisation.id,
      last_signed_in_org: organisation.id,
      owned_organisations: [organisation]
    }
  end

  def user_with_organisation_factory do
    organisation = insert(:organisation)
    # Use consistent sequence pattern
    unique_email = "#{Base.encode16(:crypto.strong_rand_bytes(10), case: :lower)}@wmail.com"

    %User{
      name: "wrafts user",
      email: unique_email,
      email_verify: true,
      role_names: ["superadmin"],
      password: "encrypt",
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      current_org_id: organisation.id,
      owned_organisations: [organisation]
    }
  end

  def organisation_factory do
    %Organisation{
      name: sequence(:name, &"organisation-#{&1}"),
      legal_name: sequence(:legal_name, &"Legal name-#{&1}"),
      address: sequence(:address, &"#{&1} th cross #{&1} th building"),
      gstin: sequence(:gstin, &"32AASDGGDGDDGDG#{&1}"),
      phone: sequence(:phone, &"985222332#{&1}"),
      # Add unique integer
      email: "#{Base.encode16(:crypto.strong_rand_bytes(10), case: :lower)}@gmail.com",
      url: sequence(:url, &"acborg#{&1}@profile.com")
    }
  end

  def user_organisation_factory do
    %UserOrganisation{
      user: build(:user),
      organisation: build(:organisation)
    }
  end

  def role_factory do
    %Role{name: "superadmin", permissions: [], organisation: build(:organisation)}
  end

  def user_role_factory do
    %UserRole{
      user: build(:user),
      role: build(:role)
    }
  end

  def profile_factory do
    %Profile{
      name: "admin@wraftdocs",
      dob: Timex.shift(Timex.now(), years: -27),
      gender: "male",
      user: build(:user, name: "admin@wraftdocs")
    }
  end

  def content_type_factory do
    %ContentType{
      name: sequence(:name, &"name-#{&1}"),
      description: "A content type to create documents",
      type: Enum.random(["document", "contract"]),
      prefix: "OFFR",
      organisation: build(:organisation),
      layout: build(:layout),
      flow: build(:flow),
      theme: build(:theme)
    }
  end

  def block_factory do
    %Block{
      name: sequence(:name, &"name-#{&1}"),
      btype: sequence(:btype, &"btype-#{&1}"),
      file_url: "file/location/example.pdf",
      api_route: "http://localhost:8080/chart",
      endpoint: "blocks_api",
      dataset: %{
        data: [
          %{
            value: 10,
            label: "January"
          },
          %{
            value: 20,
            label: "February"
          },
          %{
            value: 5,
            label: "March"
          },
          %{
            value: 60,
            label: "April"
          },
          %{
            value: 80,
            label: "May"
          },
          %{
            value: 70,
            label: "June"
          },
          %{
            value: 90,
            label: "Julay"
          }
        ],
        width: 512,
        height: 512,
        backgroundColor: "transparent",
        format: "svg",
        type: "pie"
      },
      creator: build(:user),
      organisation: build(:organisation)
    }
  end

  def build_history_factory do
    {:ok, start_time} = NaiveDateTime.new(2020, 03, 17, 20, 20, 20)
    {:ok, end_time} = NaiveDateTime.new(2020, 03, 17, 20, 21, 20)

    %History{
      status: sequence(:status, &"status-#{&1}"),
      exit_code: 2,
      start_time: start_time,
      end_time: end_time,
      delay: 120_000
    }
  end

  def asset_factory do
    %Asset{
      name: sequence(:name, &"asset-#{&1}"),
      type: "layout",
      file: nil,
      creator: build(:user),
      organisation: build(:organisation)
    }
  end

  def theme_asset_factory do
    %ThemeAsset{
      theme: build(:theme),
      asset: build(:asset)
    }
  end

  def layout_factory do
    %Layout{
      name: sequence(:name, &"layout-#{&1}"),
      description: sequence(:description, &"layout for document-#{&1}"),
      width: :rand.uniform(16),
      height: :rand.uniform(16),
      unit: sequence(:name, &"layout-#{&1}"),
      organisation: build(:organisation),
      engine: build(:engine)
    }
  end

  def layout_asset_factory do
    %LayoutAsset{
      layout: build(:layout),
      asset: build(:asset),
      creator: build(:user)
    }
  end

  def engine_factory do
    %Engine{
      name: sequence(:name, &"engine-#{&1}"),
      api_route: sequence(:api_route, &"localhost:4000/api/#{&1}")
    }
  end

  # In your factory file, ensure the instance factory creates proper associations:
def instance_factory(attrs) do
  creator = Map.get(attrs, :creator) || build(:user_with_organisation)
  creator_org = List.first(creator.owned_organisations)

  content_type =
    build(:content_type,
      organisation: creator_org,
      flow: build(:flow, organisation: creator_org)
    )

  instance =
    %Instance{
      instance_id: sequence(:instance_id, &"Prefix#{&1}"),
      raw: "Content",
      serialized: %{
        "title" => "Title of the content",
        "body" => "Body of the content"
      },
      editable: true,
      state: build(:state, organisation: creator_org, flow: content_type.flow),
      content_type: content_type,
      creator: creator,
      vendor: build(:vendor, organisation: creator_org),
      allowed_users: [creator.id],
      organisation: creator_org,
      meta: nil,
      type: 1
    }

  merge_attributes(instance, attrs)
end


  def instance_version_factory do
    %Version{
      version_number: 1,
      raw: "Content",
      serialized: %{title: "Title of the content", body: "Body of the content"},
      content: build(:instance),
      # Add explicit type to avoid nil comparison
      type: "save"
      content: build(:instance),
      # Add explicit type to avoid nil comparison
      type: "save"
    }
  end

  def state_factory do
    %State{
      state: sequence(:state, &"state-#{&1}"),
      order: sequence(:order, & &1),
      organisation: build(:organisation),
      flow: build(:flow)
    }
  end

  def state_users_factory do
    %StateUser{
      state: build(:state),
      user: build(:user)
    }
  end

  def content_collab_factory do
    %ContentCollaboration{
      content: build(:instance),
      user: build(:user),
      state: build(:state),
      # Assuming these are the roles in @roles
      role: Enum.random([:suggestor, :viewer, :editor]),
      # Default status
      status: :pending,
      invited_by: build(:user),
      # Default to nil
      revoked_by: nil,
      # Default to nil
      revoked_at: nil
    }
  end

  def flow_factory do
    %Flow{
      name: sequence(:name, &"flow-#{&1}"),
      organisation: build(:organisation),
      controlled: false,
      creator: build(:user)
    }
  end

  def contry_factory do
    %Country{
      country_name: sequence(:country_name, &"country-#{&1}"),
      country_code: sequence(:country_code, &"243432#{&1}"),
      calling_code: sequence(:calling_code, &"3343#{&1}")
    }
  end

  def data_template_factory do
    %DataTemplate{
      title: sequence(:title, &"title-#{&1}"),
      title_template: sequence(:title_template, &"title-[client]-#{&1}"),
      data: sequence(:data, &"data-#{&1}"),
      serialized: %{
        "data" =>
          Jason.encode!(%{
            "type" => "doc",
            "content" => [
              %{
                "type" => "paragraph",
                "content" => [
                  %{"type" => "text", "text" => "Sample template"}
                ]
              }
            ]
          })
      },
      content_type: build(:content_type)
    }
  end

  def theme_factory do
    %Theme{
      name: sequence(:name, &"Official Letter Theme-#{&1}"),
      font: sequence(:font, &"Malery-#{&1}"),
      typescale: %{h1: "10", p: "6", h2: "8"},
      body_color: sequence(:body_color, &"#eeff0#{&1}"),
      primary_color: sequence(:primary_color, &"#eeff0#{&1}"),
      secondary_color: sequence(:secondary_color, &"#eeff0#{&1}"),
      organisation: build(:organisation),
      creator: build(:user)
    }
  end

  def block_template_factory do
    %BlockTemplate{
      title: sequence(:title, &"BlockTemplate title #{&1} "),
      body: sequence(:body, &"BlockTemplate body #{&1} "),
      serialized: sequence(:serialized, &"BlockTemplate serialized #{&1} "),
      organisation: build(:organisation),
      creator: build(:user)
    }
  end

  def comment_factory do
    %Comment{
      comment: sequence(:comment, &"C comment #{&1} "),
      is_parent: true,
      master: "instance",
      master_id: "sdgasdfs2262dsf32a2sd",
      user: build(:user),
      organisation: build(:organisation)
    }
  end

  def approval_system_factory do
    %ApprovalSystem{
      name: "Review",
      flow: build(:flow),
      pre_state: build(:state),
      post_state: build(:state),
      approver: build(:user)
    }
  end

  def field_type_factory do
    %FieldType{
      name: sequence(:name, &"String #{&1}"),
      meta: %{},
      validations: [
        %{
          validation: %{"rule" => "required", "value" => true},
          error_message: "This field is required"
        }
      ],
      description: "Text field"
    }
  end

  def field_factory do
    %Field{
      name: sequence(:name, &"Field name #{&1}"),
      description: sequence(:desription, &"Field description #{&1}"),
      field_type: build(:field_type)
    }
  end

  def content_type_field_factory do
    %ContentTypeField{
      content_type: build(:content_type),
      field: build(:field)
    }
  end

  def counter_factory do
    %Counter{
      subject: sequence(:subject, &"Subject:#{&1}"),
      count: Enum.random(1..100)
    }
  end

  def auth_token_factory do
    %AuthToken{
      value: "token",
      token_type: "password_verify",
      expiry_datetime: Timex.shift(Timex.now(), days: 1),
      user: build(:user)
    }
  end

  def pipeline_factory do
    %Pipeline{
      name: sequence(:name, &"Pipeline-#{&1}"),
      api_route: sequence(:api_route, &"clinet-#{&1}.crm-#{&1}.com"),
      creator: build(:user),
      organisation: build(:organisation)
    }
  end

  def pipe_stage_factory do
    %Stage{
      pipeline: build(:pipeline),
      content_type: build(:content_type),
      data_template: build(:data_template),
      state: build(:state),
      creator: build(:user)
    }
  end

  def trigger_history_factory do
    {:ok, start_time} = NaiveDateTime.new(2020, 03, 17, 20, 20, 20)
    {:ok, end_time} = NaiveDateTime.new(2020, 03, 17, 20, 21, 20)
    duration = Timex.diff(end_time, start_time, :milliseconds)
    zip_file = DateTime.to_iso8601(Timex.now())

    %TriggerHistory{
      data: %{name: sequence(:name, &"Name-#{&1}")},
      error: %{error: sequence(:error, &"error_reason-#{&1}")},
      state: Enum.random(1..6),
      pipeline: build(:pipeline),
      creator: build(:user),
      start_time: start_time,
      end_time: end_time,
      duration: duration,
      zip_file: "build-#{zip_file}"
    }
  end

  def plan_factory do
    %WraftDoc.Enterprise.Plan{
      name: sequence(:name, &"Plan-#{&1}"),
      description: sequence(:description, &"Plan Description-#{&1}"),
      features: ["feature_a", "feature_b", "feature_c"],
      product_id: sequence(:product_id, &"prod_#{&1}"),
      plan_id: sequence(:plan_id, &"plan_#{&1}"),
      plan_amount: "#{Enum.random(10..500)}",
      billing_interval: Enum.random([:month, :year]),
      type: Enum.random([:free, :regular, :enterprise]),
      currency: "USD",
      payment_link: "https://example.com/payment/#{System.unique_integer()}",
      is_active?: true,
      organisation: build(:organisation),
      coupon: build(:coupon)
    }
  end

  def membership_factory do
    start_date = Timex.now()
    end_date = Timex.shift(start_date, days: 30)

    %Membership{
      organisation: build(:organisation),
      plan: build(:plan),
      start_date: Timex.now(),
      end_date: end_date,
      plan_duration: Enum.random([14, 30, 365]),
      is_expired: false
    }
  end

  def payment_factory do
    start_date = Timex.now()
    end_date = Timex.shift(start_date, days: 30)

    %Payment{
      organisation: build(:organisation),
      creator: build(:user),
      membership: build(:membership),
      razorpay_id: sequence(:invoice, &"Razorpay-#{&1}"),
      start_date: start_date,
      end_date: end_date,
      invoice_number: sequence(:invoice, &"WRAFT-INVOICE-#{&1}"),
      amount: Enum.random(1000..2000) / 1,
      action: Enum.random(1..3),
      status: Enum.random([1, 2, 3]),
      meta: %{id: sequence(:invoice, &"Razorpay-#{&1}")},
      from_plan: build(:plan, coupon: nil),
      to_plan: build(:plan, coupon: nil)
    }
  end

  def coupon_factory do
    %WraftDoc.Billing.Coupon{
      name: sequence(:name, &"Coupon-#{&1}"),
      description: "Discount for special users",
      coupon_id: sequence(:coupon_id, &"CPN-#{&1}"),
      status: Enum.random([:active, :expired, :archived]),
      type: Enum.random([:percentage, :flat]),
      coupon_code: sequence(:coupon_code, &"DISCOUNT#{&1}"),
      amount: "#{Enum.random(5..50)}",
      currency: "USD",
      recurring: Enum.random([true, false]),
      maximum_recurring_intervals: Enum.random([nil, 3, 6]),
      start_date: Timex.now(),
      expiry_date: Timex.shift(Timex.now(), days: Enum.random(30..180)),
      usage_limit: Enum.random([nil, 50, 100]),
      times_used: Enum.random(0..10),
      creator: build(:internal_user)
    }
  end

  def vendor_factory do
    %WraftDoc.Vendors.Vendor{
      name: sequence(:name, &"Vendor name #{&1} "),
      email: sequence(:email, &"vendor#{&1}@example.com"),
      phone: sequence(:phone, &"555-000-#{String.pad_leading("#{&1}", 4, "0")}"),
      address: sequence(:address, &"#{&1} Main Street"),
      city: sequence(:city, &"City #{&1}"),
      country: sequence(:country, &"Country #{&1}"),
      website: sequence(:website, &"https://vendor#{&1}.com"),
      reg_no: sequence(:reg_no, &"REG#{String.pad_leading("#{&1}", 8, "0")}"),
      contact_person: sequence(:contact_person, &"Contact Person #{&1}"),
      creator: build(:user),
      organisation: build(:organisation)
    }
  end

  def vendor_contact_factory do
    %WraftDoc.Vendors.VendorContact{
      name: sequence(:name, &"Contact #{&1}"),
      email: sequence(:email, &"contact#{&1}@vendor.com"),
      phone: sequence(:phone, &"555-100-#{String.pad_leading("#{&1}", 4, "0")}"),
      job_title: sequence(:job_title, &"Job Title #{&1}"),
      vendor: build(:vendor)
    }
  end

  def content_type_role_factory do
    %ContentTypeRole{
      content_type: build(:content_type),
      role: build(:role)
    }
  end

  def organisation_field_factory do
    %OrganisationField{
      name: sequence(:name, &"Field name #{&1}"),
      description: sequence(:desription, &"Field description #{&1}"),
      organisation: build(:organisation),
      field_type: build(:field_type)
    }
  end

  def instance_approval_system_factory do
    %InstanceApprovalSystem{
      flag: false,
      instance: build(:instance),
      approval_system: build(:approval_system)
    }
  end

  def activity_factory do
    %Activity{
      action: sequence(:activity, &"Activity#{&1}"),
      actor: "6122-d5sf-15sdf1-2s56df",
      object: sequence(:object, &"Object#{&1}"),
      target: sequence(:target, &"Target#{&1}"),
      inserted_at: Timex.now()
    }
  end

  def audience_factory do
    %Audience{
      activity: build(:activity),
      user: build(:user)
    }
  end

  def collection_form_factory do
    %CollectionForm{
      title: "WraftDoc",
      description: "WraftDoc Des"
    }
  end

  def collection_form_field_factory do
    %CollectionFormField{
      name: "WraftDoc",
      description: "WraftDoc des",
      collection_form: build(:collection_form)
    }
  end

  def role_group_factory do
    %RoleGroup{
      name: sequence(:name, &"Role group-#{&1}"),
      description: sequence(:description, &"Role group-#{&1}"),
      organisation: build(:organisation)
    }
  end

  def waiting_list_factory do
    %WaitingList{
      first_name: "wraft",
      last_name: "user",
      email: sequence(:email, &"wraftuser-#{&1}@wmail.com"),
      status: "pending"
    }
  end

  def permission_factory do
    %Permission{
      name: sequence(:name, &"permission-#{&1}"),
      resource: sequence(:resource, &"resource-#{&1}"),
      action: sequence(:action, &"action-#{&1}")
    }
  end

  def internal_user_factory do
    %InternalUser{
      email: sequence(:email, &"wraftuser-#{&1}@wmail.com"),
      password: "encrypt",
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      is_deactivated: false
    }
  end

  def invited_user_factory do
    %InvitedUser{
      email: sequence(:email, &"wraftuser-#{&1}@wmail.com"),
      status: "invited",
      organisation: build(:organisation)
    }
  end

  def form_factory do
    %Form{
      description: sequence(:description, &"description-#{&1}"),
      name: sequence(:name, &"name-#{&1}"),
      prefix: sequence(:prefix, &"prefix-#{&1}"),
      status: Enum.random([:active, :inactive]),
      organisation: build(:organisation),
      creator: build(:user)
    }
  end

  def form_field_factory do
    %FormField{
      order: sequence(:order, & &1),
      validations: [
        %{
          validation: %{"rule" => "required", "value" => Enum.random([true, false])},
          error_message: "This field is required."
        },
        %{
          validation: %{"rule" => "email"},
          error_message: "Please enter a valid email address."
        }
      ],
      form: build(:form),
      field: build(:field)
    }
  end

  def form_entry_factory do
    %FormEntry{
      data: %{
        1 => %{field_id: 1, value: "random@gmail.com"},
        2 => %{field_id: 12, value: "random string"}
      },
      status: Enum.random([:submitted, :draft]),
      form: build(:form),
      user: build(:user)
    }
  end

  def form_pipeline_factory do
    %FormPipeline{
      form: build(:form),
      pipeline: build(:pipeline)
    }
  end

  def form_mapping_factory do
    %FormMapping{
      form: build(:form),
      pipe_stage: build(:pipe_stage),
      mapping: [
        %{
          source: %{"id" => Ecto.UUID.generate(), "name" => sequence(:name, &"name-#{&1}")},
          destination: %{
            "id" => Ecto.UUID.generate(),
            "name" => sequence(:name, &"name-#{&1}")
          }
        },
        %{
          source: %{"id" => Ecto.UUID.generate(), "name" => sequence(:name, &"name-#{&1}")},
          destination: %{
            "id" => Ecto.UUID.generate(),
            "name" => sequence(:name, &"name-#{&1}")
          }
        }
      ]
    }
  end

  def api_key_factory do
    organisation = build(:organisation)
    user = build(:user)

    # Generate a sample API key
    prefix = Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)

    encoded = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    random_part = binary_part(encoded, 0, 32)

    full_key = "wraft_#{prefix}_#{random_part}"

    %ApiKey{
      name: sequence(:api_key_name, &"API Key #{&1}"),
      key_hash: Bcrypt.hash_pwd_salt(full_key),
      key_prefix: prefix,
      organisation: organisation,
      user: user,
      created_by: user,
      expires_at: nil,
      is_active: true,
      rate_limit: 1000,
      ip_whitelist: [],
      last_used_at: nil,
      usage_count: 0,
      metadata: %{}
    }
  end
end
