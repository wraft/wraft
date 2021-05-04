# Script for populating the \base. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     WraftDoc.Repo.insert!(%WraftDoc.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias WraftDoc.{
  Repo,
  Account.Role,
  Account.User,
  Account.UserRole,
  Account.Profile,
  Document.Engine,
  Document.Layout,
  Document.ContentType,
  Document.Instance,
  Document.Theme,
  Enterprise.Organisation,
  Enterprise.Flow,
  Enterprise.Flow.State,
  Enterprise.Plan,
  Document.FieldType,
  Document.ContentTypeField,
  Document.Counter,
  Document.DataTemplate
}

# Populate database with roles
with nil <- Repo.get_by(Role, name: "admin") do
  Repo.insert!(%Role{name: "admin"})
end

with nil <- Repo.get_by(Role, name: "super_admin") do
  Repo.insert!(%Role{name: "super_admin"})
end

with nil <- Repo.get_by(Role, name: "user") do
  Repo.insert!(%Role{name: "user"})
end

# Populate DB with admin user and profile

# Populate DB with one organisation
%{id: role_id} = Repo.get_by(Role, name: "super_admin")

organisation =
  case Repo.get_by(Organisation, email: "hello@aurut.com") do
    %Organisation{} = organisation ->
      organisation

    _ ->
      Repo.insert!(%Organisation{
        name: "Functionary Labs Pvt Ltd.",
        legal_name: "Functionary Labs Pvt Ltd",
        address: "#24, Caravel Building",
        name_of_ceo: "Muneef Hameed",
        name_of_cto: "Salsabeel K",
        email: "hello@aurut.com"
      })
  end

user_params = %{
  name: "Admin",
  email: "admin@wraftdocs.com",
  email_verify: true,
  password: "Admin@WraftDocs",
  organisation_id: organisation.id
}

user =
  case Repo.get_by(User, name: "Admin") do
    %User{} = user ->
      user

    _ ->
      %User{} |> User.changeset(user_params) |> Repo.insert!()
  end

with nil <- Repo.get_by(UserRole, user_id: user.id) do
  Repo.insert!(%UserRole{user_id: user.id, role_id: role_id})
end

with nil <- Repo.get_by(Profile, name: "Admin") do
  Repo.insert!(%Profile{name: "Admin", user_id: user.id})
end

# Populate engine
engine =
  case Repo.get_by(Engine, name: "PDF") do
    %Engine{} = engine -> engine
    _ -> Repo.insert!(%Engine{name: "PDF"})
  end

with nil <- Repo.get_by(Engine, name: "LaTex") do
  Repo.insert!(%Engine{name: "LaTex"})
end

with nil <- Repo.get_by(Engine, name: "Pandoc") do
  Repo.insert!(%Engine{name: "Pandoc"})
end

# Populate layout

layout =
  case Repo.get_by(Layout, slug: "pletter") do
    %Layout{} = layout ->
      layout

    _ ->
      Repo.insert!(%Layout{
        name: "Official Letter",
        description: "An official letter",
        width: 30.0,
        height: 40.0,
        unit: "cm",
        slug: "pletter",
        engine_id: engine.id,
        creator_id: user.id,
        organisation_id: organisation.id
      })
  end

# Populate fields
field =
  case Repo.get_by(FieldType, name: "String") do
    %FieldType{} = field -> field
    _ -> Repo.insert!(%FieldType{name: "String", creator_id: user.id})
  end

# Populate flow
flow =
  case Repo.get_by(Flow, name: "Flow 1") do
    %Flow{} = flow ->
      flow

    _ ->
      Repo.insert!(%Flow{
        name: "Flow 1",
        organisation_id: organisation.id,
        creator_id: user.id
      })
  end

# Populate Content Type
content_type =
  case Repo.get_by(ContentType, prefix: "OFFLET") do
    %ContentType{} = content_type ->
      content_type

    _ ->
      Repo.insert!(%ContentType{
        name: "Offer Letter",
        description: "An offer letter",
        prefix: "OFFLET",
        layout_id: layout.id,
        creator_id: user.id,
        organisation_id: organisation.id,
        flow_id: flow.id,
        color: "#fff"
      })
  end

# Populate content type fields
with nil <- Repo.get_by(ContentTypeField, name: "employee") do
  Repo.insert!(%ContentTypeField{
    name: "employee",
    content_type_id: content_type.id,
    field_type_id: field.id
  })
end

# Populate State
state =
  case Repo.get_by(State, state: "Published") do
    %State{} = state ->
      state

    _ ->
      Repo.insert!(%State{
        state: "Published",
        order: 1,
        creator_id: user.id,
        organisation_id: organisation.id,
        flow_id: flow.id
      })
  end

# Populate Instance
with nil <- Repo.get_by(Instance, instance_id: "OFFLET0001") do
  Repo.insert!(%Instance{
    instance_id: "OFFLET0001",
    raw: "Hi John Doe, We offer you the position of Elixir developer",
    serialized: %{
      title: "Offer Letter for Elixir",
      body: "Hi John Doe, We offer you the position of Elixir developer"
    },
    creator_id: user.id,
    content_type_id: content_type.id,
    state_id: state.id
  })
end

# Populate Counter
with nil <- Repo.get_by(Counter, subject: "ContentType:#{content_type.id}") do
  Repo.insert!(%Counter{
    subject: "ContentType:#{content_type.id}",
    count: 1
  })
end

# Populate theme
with nil <- Repo.get_by(Theme, font: "Malery") do
  Repo.insert!(%Theme{
    name: "Offer letter theme",
    font: "Malery",
    typescale: %{h1: 10, h2: 8, p: 6},
    creator_id: user.id,
    organisation_id: organisation.id
  })
end

# Populate data template
with nil <- Repo.get_by(DataTemplate, content_type_id: content_type.id) do
  Repo.insert!(%DataTemplate{
    title: "Offer letter tempalate",
    title_template: "Offer Letter for [employee]",
    data: "Hi [employee], we welcome you to our [company]",
    content_type_id: content_type.id,
    creator_id: user.id
  })
end

# Populate plans
with nil <- Repo.get_by(Plan, name: "Free Trial") do
  Repo.insert!(%Plan{
    name: "Free Trial",
    description: "Free trial where users can try out all the features",
    yearly_amount: 0,
    monthly_amount: 0
  })
end

with nil <- Repo.get_by(Plan, name: "Premium") do
  Repo.insert!(%Plan{
    name: "Premium",
    description: "Premium plan with premium features only",
    yearly_amount: 0,
    monthly_amount: 0
  })
end

with nil <- Repo.get_by(Plan, name: "Pro") do
  Repo.insert!(%Plan{
    name: "Pro",
    description: "Pro plan suitable for enterprises",
    yearly_amount: 0,
    monthly_amount: 0
  })
end
