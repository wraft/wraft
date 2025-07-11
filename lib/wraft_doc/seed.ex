defmodule WraftDoc.Seed do
  @moduledoc """
    Smaller functions to seed various tables.
  """

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
  alias WraftDoc.Enterprise.Vendor
  alias WraftDoc.Fields.Field
  alias WraftDoc.Fields.FieldType
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.Layouts.LayoutAsset
  alias WraftDoc.Repo
  alias WraftDoc.Themes.Theme
  alias WraftDoc.Themes.ThemeAsset

  require Logger

  def generate_user(username, email) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        user

      nil ->
        user =
          Repo.insert!(%User{
            name: username,
            email: email,
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
  end

  def generate_user do
    user =
      Repo.insert!(%User{
        name: Faker.Person.first_name() <> " " <> Faker.Person.last_name(),
        email: Faker.Internet.email(),
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
        name: Faker.Company.name(),
        legal_name: Faker.Company.name(),
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
    Repo.get_by(Profile, user_id: user.id) ||
      Repo.insert!(%Profile{
        name: user.name,
        profile_pic: %{file_name: "avatar.png", updated_at: nil},
        dob: Faker.Date.date_of_birth(18..60),
        gender: Enum.random(["Male", "Female"]),
        user_id: user.id,
        country_id: country.id
      })
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

  def seed_asset(user, organisation, type) do
    Repo.insert!(%Asset{
      name: Faker.Lorem.word(),
      type: type,
      creator_id: user.id,
      organisation_id: organisation.id
    })
  end

  def seed_layout_and_layout_asset(user, organisation, engine) do
    # Insert layout
    layout =
      Repo.insert!(%Layout{
        name: Enum.join(Faker.Lorem.words(2), " "),
        description: Faker.Lorem.sentence(),
        width: Enum.random(1..100) * 1.0,
        height: Enum.random(1..100) * 1.0,
        unit: Enum.random(["cm", "mm"]),
        slug: "contract",
        engine_id: engine.id,
        creator_id: user.id,
        organisation_id: organisation.id
      })

    asset = seed_asset(user, organisation, "layout")

    # Insert layout asset
    Repo.insert!(%LayoutAsset{
      layout_id: layout.id,
      asset_id: asset.id,
      creator_id: user.id
    })

    layout
  end

  def seed_theme_and_theme_asset(user, organisation) do
    # Insert theme
    theme =
      Repo.insert!(%Theme{
        name: Enum.join(Faker.Lorem.words(2), " "),
        font: Faker.Lorem.word(),
        typescale: %{h1: 10, h2: 8, p: 6},
        body_color: Faker.Color.rgb_hex(),
        primary_color: Faker.Color.rgb_hex(),
        secondary_color: Faker.Color.rgb_hex(),
        creator_id: user.id,
        organisation_id: organisation.id
      })

    asset = seed_asset(user, organisation, "theme")
    # Insert theme asset
    Repo.insert!(%ThemeAsset{
      theme_id: theme.id,
      asset_id: asset.id
    })

    theme
  end

  def seed_flow(user, organisation) do
    Repo.insert!(%Flow{
      name: Faker.Lorem.word(),
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
        name:
          Enum.random([
            "Offer Letter",
            "Service Contract",
            "Proposal Branding",
            "Staff NDA",
            "Visiting Card"
          ]),
        description: Faker.Lorem.sentence(),
        color: Faker.Color.rgb_hex(),
        prefix: Faker.Lorem.word(),
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
      Repo.insert!(%State{
        state: state,
        order: order,
        creator_id: user.id,
        organisation_id: organisation.id,
        flow_id: flow.id
      })
    end
  end

  def seed_vendor(user, organisation) do
    Repo.insert!(%Vendor{
      name: Faker.Company.name(),
      email: Faker.Internet.email(),
      phone: Phone.EnGb.number(),
      address: Faker.Address.En.street_address(),
      gstin: Faker.Code.iban(),
      reg_no: Faker.Code.isbn(),
      contact_person: Faker.Person.name(),
      organisation_id: organisation.id,
      creator_id: user.id
    })
  end

  def seed_document_instance(user, content_type, state) do
    Repo.insert!(%Instance{
      instance_id: Faker.Nato.letter_code_word(),
      raw: Faker.Company.buzzword_prefix(),
      serialized: %{
        title: Faker.Company.catch_phrase(),
        body: "Hi #{Faker.Person.name()}, We offer you the position of Elixir developer"
      },
      type: 1,
      creator_id: user.id,
      content_type_id: content_type.id,
      state_id: state.id
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
      raw: Faker.Lorem.sentence(),
      serialized: %{
        title: Enum.join(Faker.Lorem.words(4), " "),
        body: Faker.Lorem.sentence()
      },
      naration: Faker.Lorem.word(),
      author_id: user.id,
      content_id: instance.id
    })
  end

  def seed_data_template(user, content_type) do
    Repo.insert!(%DataTemplate{
      title: Enum.join(Faker.Lorem.words(3), " "),
      title_template: Enum.join(Faker.Lorem.words(4), " "),
      data: Faker.Lorem.sentence(),
      serialized: %{
        title: Enum.join(Faker.Lorem.words(4), " "),
        body: Faker.Lorem.sentence()
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

    field =
      Repo.insert!(%Field{
        name: "Employee",
        description: "Name of the employee",
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
  end
end
