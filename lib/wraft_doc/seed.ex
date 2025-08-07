defmodule WraftDoc.Seed do
  @moduledoc """
    Smaller functions to seed various tables.
  """

  alias Faker.Address.En, as: FakerAddressEn
  alias Faker.Code
  alias Faker.Company
  alias Faker.Internet
  alias Faker.Person
  alias Faker.Phone
  alias WraftDoc.Account.Profile
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Blocks.Block
  alias WraftDoc.BlockTemplates.BlockTemplate
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.ContentTypes.ContentTypeField
  alias WraftDoc.ContentTypes.ContentTypeRole
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents.Counter
  alias WraftDoc.Documents.Engine
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Instance.History
  alias WraftDoc.Documents.Instance.Version
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.Membership
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.StateUser
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset
  alias WraftDoc.Vendors.Vendor

  require Logger

  @instance_markdown "Dear **John Doe**,\n\nWe are pleased to offer you the position of **People Operations Manager** at Acme Corporation. This letter confirms the details of our employment offer:\n\nPosition: **People Operations Manager**\n\nDepartment: **People & Culture**\n\nStart Date: **03/29/2023**\n\nStarting Salary: Rs. **6 LPA**\n\nAcme Corporation is a company that grows and is enriched by the contributions of its employees, and we look forward to your continued enthusiasm. We believe that your Employment with Acme Corporation will be both personally and professionally rewarding.\n\nSincerely,\n\n.\n\n**Sharmila VK**\n\n**Human Resources Director**\n\n**Acme Corporation**\n"

  @instance_serialized """
  {\"type\":\"doc\",\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Dear \"},{\"type\":\"holder\",\"attrs\":{\"named\":\"John Doe\",\"name\":\"Employee Name\",\"id\":\"d5b72d83-17a9-474b-904c-9086fd70c289\"},\"marks\":[{\"type\":\"bold\"}]},{\"type\":\"text\",\"text\":\",\"}]},{\"type\":\"paragraph\"},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"We are pleased to offer you the position of \"},{\"type\":\"holder\",\"attrs\":{\"named\":\"People Operations Manager\",\"name\":\"Position\",\"id\":\"2ea4297f-6a9f-4ca9-8845-9905bf418c20\"},\"marks\":[{\"type\":\"bold\"}]},{\"type\":\"text\",\"text\":\" at Acme Corporation. This letter confirms the details of our employment offer:\"}]},{\"type\":\"paragraph\"},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Position: \"},{\"type\":\"holder\",\"attrs\":{\"named\":\"People Operations Manager\",\"name\":\"Position\",\"id\":\"2ea4297f-6a9f-4ca9-8845-9905bf418c20\"},\"marks\":[{\"type\":\"bold\"}]}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Department: \"},{\"type\":\"holder\",\"attrs\":{\"named\":\"People & Culture\",\"name\":\"Department\",\"id\":\"afd752a3-42a3-4a74-a29b-139e13e22ad7\"},\"marks\":[{\"type\":\"bold\"}]}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Start Date: \"},{\"type\":\"holder\",\"attrs\":{\"named\":\"03/29/2023\",\"name\":\"Start Date\",\"id\":\"70da7fc6-cdb3-46cf-9edc-0d2b85481cee\"},\"marks\":[{\"type\":\"bold\"}]}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Starting Salary: Rs. \"},{\"type\":\"holder\",\"attrs\":{\"named\":\"6 LPA\",\"name\":\"Salary amount\",\"id\":\"d3ac2c53-e2ec-4dac-9eb1-46b865cedc10\"},\"marks\":[{\"type\":\"bold\"}]}]},{\"type\":\"paragraph\"},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Acme Corporation is a company that grows and is enriched by the contributions of its employees, and we look forward to your continued enthusiasm. We believe that your Employment with Acme Corporation will be both personally and professionally rewarding.\"}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"Sincerely,\"}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\".\"}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"marks\":[{\"type\":\"bold\"}],\"text\":\"Sharmila VK\"}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"marks\":[{\"type\":\"bold\"}],\"text\":\"Human Resources Director\"}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"marks\":[{\"type\":\"bold\"}],\"text\":\"Acme Corporation\"}]},{\"type\":\"paragraph\"}]}
  """

  @fields """
    {\"Employee Name\":\"John Doe\",\"Position\":\"People Operations Manager\",\"Department\":\"People & Culture\",\"Salary amount\":\"6 LPA\",\"Start date\":\"03/29/2023\"}
  """

  def generate_user(username, email) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        user

      nil ->
        user =
          Repo.insert!(%User{
            name: username,
            email: email,
            encrypted_password: Bcrypt.hash_pwd_salt("demo@1234"),
            email_verify: true,
            deleted_at: nil
          })

        organisation =
          Repo.insert!(%Organisation{name: "Personal", email: user.email, creator_id: user.id})

        Enterprise.create_free_subscription(organisation.id)

        # Update the user with the last signed in organisation
        user =
          user
          |> Ecto.Changeset.change(%{last_signed_in_org: organisation.id})
          |> Repo.update!()

        seed_user_roles(user, organisation)
        Repo.insert!(%UserOrganisation{user_id: user.id, organisation_id: organisation.id})
        user
    end
  end

  def generate_user do
    user =
      Repo.insert!(%User{
        name: Person.first_name() <> " " <> Person.last_name(),
        email: Internet.email(),
        encrypted_password: Bcrypt.hash_pwd_salt("password"),
        email_verify: true,
        deleted_at: nil
      })

    organisation =
      Repo.insert!(%Organisation{name: "Personal", email: user.email, creator_id: user.id})

    Enterprise.create_free_subscription(organisation.id)

    # Update the user with the last signed in organisation
    user =
      user
      |> Ecto.Changeset.change(%{last_signed_in_org: organisation.id})
      |> Repo.update!()

    seed_user_roles(user, organisation)
    Repo.insert!(%UserOrganisation{user_id: user.id, organisation_id: organisation.id})
    user
  end

  def seed_user_roles(user, %{name: "Personal"} = organisation) do
    role =
      Repo.insert!(%Role{name: "superadmin", permissions: [], organisation_id: organisation.id})

    Repo.insert!(%UserRole{user_id: user.id, role_id: role.id})
    role
  end

  def seed_user_roles(user, organisation) do
    role =
      Repo.insert!(%Role{
        name: "superadmin",
        permissions: [],
        organisation_id: organisation.id
      })

    Repo.insert!(%UserRole{
      user_id: user.id,
      role_id: role.id
    })

    role
  end

  def seed_user_organisation(user) do
    organisation =
      Repo.insert!(%Organisation{
        name: "Acme Corporation",
        legal_name: "Acme Corporation Ltd",
        address: Faker.Address.street_address(),
        name_of_ceo: Faker.Person.name(),
        name_of_cto: Faker.Person.name(),
        gstin: Faker.String.base64(15),
        corporate_id: Faker.String.base64(21),
        phone: Phone.EnGb.number(),
        email: Faker.Internet.email(),
        creator_id: user.id
      })

    Repo.insert!(%UserOrganisation{user_id: user.id, organisation_id: organisation.id})
    organisation
  end

  def seed_profile(user, country) do
    user =
      Repo.get_by(Profile, user_id: user.id) ||
        Repo.insert!(%Profile{
          name: user.name,
          dob: Faker.Date.date_of_birth(18..60),
          gender: Enum.random(["Male", "Female"]),
          user_id: user.id,
          country_id: country.id
        })

    profile_pic = %Plug.Upload{
      path: Path.join(File.cwd!(), "priv/static/images/gradient.png"),
      filename: "gradient.png"
    }

    user
    |> Profile.propic_changeset(%{profile_pic: profile_pic})
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        Repo.update!(changeset)

      %Ecto.Changeset{valid?: false} ->
        user
    end
  end

  def seed_engine do
    # Insert PDF engine
    pdf_engine = Repo.insert!(%Engine{name: "PDF", api_route: "/api/pdf_engine"})
    # Insert LaTex engine
    latex_engine = Repo.insert!(%Engine{name: "LaTex", api_route: "/api/latex_engine"})
    # Insert Pandoc engine
    pandoc_engine = Repo.insert!(%Engine{name: "Pandoc", api_route: "/api/pandoc_engine"})

    pandoc_typst_engine =
      Repo.insert!(%Engine{name: "Pandoc + Typst", api_route: "/api/pandoc_typst_engine"})

    [pdf_engine, latex_engine, pandoc_engine, pandoc_typst_engine]
  end

  def seed_asset(user, organisation, type, file) do
    asset =
      Repo.insert!(%Asset{
        name: Path.rootname(file.filename),
        type: type,
        creator_id: user.id,
        organisation_id: organisation.id
      })

    asset
    |> Asset.file_changeset(%{"file" => file})
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        Repo.update!(changeset)

      %Ecto.Changeset{valid?: false} ->
        asset
    end
  end

  def seed_layout_and_layout_asset(user, organisation, engine) do
    file_path = Path.join([File.cwd!(), "priv", "wraft_files", "letterhead.pdf"])

    layout_file = %Plug.Upload{
      path: file_path,
      filename: "letterhead.pdf",
      content_type: "application/pdf"
    }

    asset = seed_asset(user, organisation, "layout", layout_file)

    # Insert layout with asset_id
    Repo.insert!(%Layout{
      name: "Offer letter - layout",
      description: "A clean and structured layout specifically designed for formal offer letters",
      width: Enum.random(1..100) * 1.0,
      height: Enum.random(1..100) * 1.0,
      unit: Enum.random(["cm", "mm"]),
      slug: "pletter",
      engine_id: engine.id,
      asset_id: asset.id,
      creator_id: user.id,
      organisation_id: organisation.id
    })
  end

  def seed_theme_and_theme_asset(user, organisation) do
    # Insert theme
    theme =
      Repo.insert!(%Theme{
        name: "Offer letter - theme",
        font: "Roboto",
        typescale: %{h1: 10, h2: 8, p: 6},
        body_color: "#ffffff",
        primary_color: "#000000",
        secondary_color: "#000000",
        creator_id: user.id,
        organisation_id: organisation.id
      })

    file_paths = [
      "priv/wraft_files/Roboto/Roboto-Bold.ttf",
      "priv/wraft_files/Roboto/Roboto-BoldItalic.ttf",
      "priv/wraft_files/Roboto/Roboto-Italic.ttf",
      "priv/wraft_files/Roboto/Roboto-Regular.ttf"
    ]

    Enum.each(file_paths, fn file_path ->
      theme_file = %Plug.Upload{
        path: Path.join(File.cwd!(), file_path),
        filename: Path.basename(file_path)
      }

      asset = seed_asset(user, organisation, "theme", theme_file)

      # Insert theme asset
      Repo.insert!(%ThemeAsset{
        theme_id: theme.id,
        asset_id: asset.id
      })
    end)

    theme
  end

  def seed_flow(user, organisation) do
    Repo.insert!(%Flow{
      name: "Offer Letter - flow",
      controlled: Enum.random([true, false]),
      control_data: %{
        pre_state: "Review",
        post_state: "Publish",
        approver: user
      },
      organisation_id: organisation.id,
      creator_id: user.id
    })
  end

  def seed_content_type_and_content_type_role(user, organisation, layout, theme, flow, role) do
    content_type =
      Repo.insert!(%ContentType{
        name: "Offer Letter",
        description:
          "This Offer Letter variant helps you quickly create and customize professional-grade documents tailored for your organization's needs.",
        color: "#" <> Faker.Color.rgb_hex(),
        prefix: "WOL",
        layout_id: layout.id,
        flow_id: flow.id,
        theme_id: theme.id,
        organisation_id: organisation.id,
        creator_id: user.id
      })

    Repo.insert!(%ContentTypeRole{
      content_type_id: content_type.id,
      role_id: role.id
    })

    content_type
  end

  def seed_state(user, organisation, flow) do
    for {state, order} <- [{"Draft", 1}, {"Review", 2}, {"Published", 3}] do
      state =
        Repo.insert!(%State{
          state: state,
          order: order,
          creator_id: user.id,
          organisation_id: organisation.id,
          flow_id: flow.id
        })

      seed_state_user(user, state)

      state
    end
  end

  def seed_state_user(user, state) do
    Repo.insert!(%StateUser{
      user_id: user.id,
      state_id: state.id
    })
  end

  def seed_vendor(user, organisation) do
    Repo.insert!(%Vendor{
      name: Company.name(),
      email: Internet.email(),
      phone: Phone.EnGb.number(),
      address: FakerAddressEn.street_address(),
      city: FakerAddressEn.city(),
      country: FakerAddressEn.country(),
      reg_no: Code.isbn(),
      website: Internet.url(),
      logo: nil,
      contact_person: Person.name(),
      organisation_id: organisation.id,
      creator_id: user.id
    })
  end

  def seed_document_instance(user, organisation, content_type, state, vendor) do
    Repo.insert!(%Counter{
      subject: "ContentType:#{content_type.id}",
      count: 1
    })

    Repo.insert!(%Instance{
      instance_id: content_type.prefix <> "0001",
      raw: @instance_markdown,
      serialized: %{
        title: "Offer letter For John Doe",
        body: @instance_markdown,
        fields: @fields,
        serialized: @instance_serialized
      },
      type: 1,
      creator_id: user.id,
      content_type_id: content_type.id,
      state_id: state.id,
      vendor_id: vendor.id,
      organisation_id: organisation.id
    })
  end

  def seed_build_history(user, instance) do
    Repo.insert!(%History{
      status: Enum.random(["success", "failure"]),
      exit_code: Enum.random(0..256),
      start_time: NaiveDateTime.new!(2023, 03, 17, 20, 20, 20),
      end_time: NaiveDateTime.new!(2024, 03, 17, 20, 21, 20),
      delay: Enum.random(0..100_000),
      content_id: instance.id,
      creator_id: user.id
    })
  end

  def seed_approval_system(user, flow) do
    draft = Repo.get_by(State, state: "Draft", flow_id: flow.id)
    review = Repo.get_by(State, state: "Review", flow_id: flow.id)

    Repo.insert!(%ApprovalSystem{
      name: Faker.Company.buzzword(),
      pre_state_id: draft.id,
      post_state_id: review.id,
      flow_id: flow.id,
      approver_id: user.id,
      creator_id: user.id
    })
  end

  def seed_document_instance_version(user, instance) do
    Repo.insert!(%Version{
      version_number: Enum.random(1..10),
      raw: @instance_markdown,
      serialized: %{
        title: "Offer letter For John Doe",
        fields: @fields,
        body: @instance_markdown,
        data: @instance_serialized
      },
      naration: Faker.Lorem.word(),
      author_id: user.id,
      content_id: instance.id
    })
  end

  def seed_data_template(user, content_type) do
    Repo.insert!(%DataTemplate{
      title: "Offer letter - Template",
      title_template: "Offer letter For [Employee Name]",
      data: @instance_markdown,
      serialized: %{
        data: @instance_serialized
      },
      content_type_id: content_type.id,
      creator_id: user.id
    })
  end

  def seed_membership(organisation, plan) do
    Repo.insert!(%Membership{
      start_date: NaiveDateTime.new!(2023, 03, 17, 20, 20, 20),
      end_date: NaiveDateTime.new!(2024, 03, 17, 20, 21, 20),
      plan_duration: Enum.random(1..12),
      is_expired: false,
      plan_id: plan.id,
      organisation_id: organisation.id
    })
  end

  def seed_block_and_block_template(user, organisation) do
    Repo.insert!(%Block{
      name: Faker.Commerce.product_name(),
      description: Faker.Lorem.Shakespeare.romeo_and_juliet(),
      btype: Faker.Industry.sub_sector(),
      file_url: Faker.Avatar.image_url(),
      api_route: Faker.Internet.url(),
      endpoint: Faker.Internet.image_url(),
      dataset: %{Faker.Commerce.product_name() => Faker.Lorem.words(8..12)},
      tex_chart: "pie [rotate=180]{80/january}",
      input: %{file_name: "uploads/block_input/name.csv", updated_at: nil},
      creator_id: user.id,
      organisation_id: organisation.id
    })

    Repo.insert!(%BlockTemplate{
      title: Faker.Lorem.word(),
      body: Faker.Lorem.paragraph(),
      serialized: Faker.Lorem.word(),
      creator_id: user.id,
      organisation_id: organisation.id
    })
  end

  def seed_field_and_content_type_field(content_type, organisation) do
    field_type = Repo.get_by(FieldType, name: "String")

    fields = [
      {"Employee Name", "Name of the employee"},
      {"Position", "Position of the employee"},
      {"Department", "Department of the employee"},
      {"Salary amount", "Salary of the employee"},
      {"Start date", "Start date of the employee"}
    ]

    Enum.each(fields, fn {name, description} ->
      field =
        Repo.insert!(%Field{
          name: name,
          description: description,
          meta: %{
            property1: Faker.Lorem.sentence(),
            property2: Faker.Lorem.sentence()
          },
          field_type_id: field_type.id,
          organisation_id: organisation.id
        })

      Repo.insert!(%ContentTypeField{
        content_type_id: content_type.id,
        field_id: field.id
      })
    end)
  end

  def seed_dashboard_stats do
    Repo.query!("REFRESH MATERIALIZED VIEW dashboard_stats")
    Repo.query!("REFRESH MATERIALIZED VIEW documents_by_content_type_stats")
  end
end
