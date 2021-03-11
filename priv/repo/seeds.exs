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
Repo.insert!(%Role{name: "admin"})
Repo.insert!(%Role{name: "user"})

# Populate DB with admin user and profile
%{id: id} =   Repo.get_by(Role, name: "admin")

# Populate DB with one organisation
organisation =
  Repo.insert!(%Organisation{
    name: "Functionary Labs Pvt Ltd.",
    legal_name: "Functionary Labs Pvt Ltd",
    address: "#24, Caravel Building",
    name_of_ceo: "Muneef Hameed",
    name_of_cto: "Salsabeel K",
    email: "hello@aurut.com"
  })

user_params = %{
  name: "Admin",
  email: "admin@wraftdocs.com",
  role_id: id,
  email_verify: true,
  password: "Admin@WraftDocs",
  organisation_id: organisation.id
}

user = %User{} |> User.changeset(user_params) |> Repo.insert!()
Repo.insert!(%Profile{name: "Admin", user_id: user.id})

# Populate engine
engine = Repo.insert!(%Engine{name: "PDF"})
Repo.insert!(%Engine{name: "LaTex"})
Repo.insert!(%Engine{name: "Pandoc"})

# Populate layout
layout =
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

# Populate fields
field = Repo.insert!(%FieldType{name: "String", creator_id: user.id})

# Populate flow
flow =
  Repo.insert!(%Flow{
    name: "Flow 1",
    organisation_id: organisation.id,
    creator_id: user.id
  })

# Populate Content Type
content_type =
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

# Populate content type fields
Repo.insert!(%ContentTypeField{name: "employee", content_type_id: content_type.id, field_type_id: field.id})

# Populate State
state =
  Repo.insert!(%State{
    state: "Published",
    order: 1,
    creator_id: user.id,
    organisation_id: organisation.id,
    flow_id: flow.id
  })

# Populate Instance
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

# Populate Counter
Repo.insert!(%Counter{
  subject: "ContentType:#{content_type.id}",
  count: 1
})

# Populate theme
Repo.insert!(%Theme{
  name: "Offer letter theme",
  font: "Malery",
  typescale: %{h1: 10, h2: 8, p: 6},
  creator_id: user.id,
  organisation_id: organisation.id
})

# Populate data template
Repo.insert!(%DataTemplate{
  title: "Offer letter tempalate",
  title_template: "Offer Letter for [employee]",
  data: "Hi [employee], we welcome you to our [company]",
  content_type_id: content_type.id,
  creator_id: user.id
})

# Populate plans
Repo.insert!(%Plan{
  name: "Free Trial",
  description: "Free trial where users can try out all the features",
  yearly_amount: 0,
  monthly_amount: 0
})

Repo.insert!(%Plan{
  name: "Premium",
  description: "Premium plan with premium features only",
  yearly_amount: 0,
  monthly_amount: 0
})

Repo.insert!(%Plan{
  name: "Pro",
  description: "Pro plan suitable for enterprises",
  yearly_amount: 0,
  monthly_amount: 0
})
