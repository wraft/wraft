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
  Authorization.Resource,
  Authorization.Permission,
  Account.Role,
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

import WraftDoc.SeedGate

# Populate database with roles

%{id: role_id} = allow_once(%Role{name: "super_admin"}, name: "super_admin")

role_user = allow_once(%Role{name: "user"}, name: "user")
role_admin = allow_once(%Role{name: "amin"}, name: "admin")

# Populate DB with admin user and profile

# # Populate DB with one organisation

organisation =
  allow_once(
    %Organisation{
      name: "Functionary Labs Pvt Ltd.",
      legal_name: "Functionary Labs Pvt Ltd",
      address: "#24, Caravel Building",
      name_of_ceo: "Muneef Hameed",
      name_of_cto: "Salsabeel K",
      email: "hello@aurut.com"
    },
    email: "hello@aurut.com"
  )

user =
  comeon_user(%{
    name: "Admin",
    email: "admin@wraftdocs.com",
    email_verify: true,
    password: "Admin@WraftDocs",
    organisation_id: organisation.id
  })

org_admin =
  comeon_user(%{
    name: "Organisation admin",
    email: "organisation@wraftdocs.com",
    email_verify: true,
    password: "Organisation@WraftDocs",
    organisation_id: organisation.id
  })

normal_user =
  comeon_user(%{
    name: "Sadique",
    email: "sadique@wraftdocs.com",
    email_verify: true,
    password: "Sadique@WraftDocs",
    organisation_id: organisation.id
  })

# case Repo.get_by(User, name: "Admin") do
#   %User{} = user ->
#     user

#   _ ->
#     %User{} |> User.changeset(user_params) |> Repo.insert!()
# end

allow_once(%UserRole{user_id: user.id, role_id: role_id}, user_id: user.id, role_id: role_id)

allow_once(%UserRole{user_id: org_admin.id, role_id: role_admin.id},
  user_id: org_admin.id,
  role_id: role_admin.id
)

allow_once(%UserRole{user_id: normal_user.id, role_id: role_user.id},
  user_id: normal_user.id,
  role_id: role_user.id
)

allow_once(%Profile{name: "Admin", user_id: user.id}, name: "Admin")

allow_once(%Profile{name: "Organisation admin", user_id: org_admin.id}, name: "Organisation admin")

allow_once(%Profile{name: "User", user_id: normal_user.id}, name: "User")

# Populate engine
engine = allow_once(%Engine{name: "PDF"}, name: "PDF")

allow_once(%Engine{name: "LaTex"}, name: "LaTex")

allow_once(%Engine{name: "Pandoc"}, name: "Pandoc")

# Populate layout

layout =
  allow_once(
    %Layout{
      name: "Official Letter",
      description: "An official letter",
      width: 30.0,
      height: 40.0,
      unit: "cm",
      slug: "pletter",
      engine_id: engine.id,
      creator_id: user.id,
      organisation_id: organisation.id
    },
    slug: "pletter"
  )

# Populate fields
field = allow_once(%FieldType{name: "String", creator_id: user.id}, name: "String")

# Populate flow
flow =
  allow_once(
    %Flow{
      name: "Flow 1",
      organisation_id: organisation.id,
      creator_id: user.id
    },
    name: "Flow 1"
  )

# Populate Content Type
content_type =
  allow_once(
    %ContentType{
      name: "Offer Letter",
      description: "An offer letter",
      prefix: "OFFLET",
      layout_id: layout.id,
      creator_id: user.id,
      organisation_id: organisation.id,
      flow_id: flow.id,
      color: "#fff"
    },
    prefix: "OFFLET"
  )

# Populate content type fields
allow_once(
  %ContentTypeField{
    name: "employee",
    content_type_id: content_type.id,
    field_type_id: field.id
  },
  name: "employee"
)

# Populate State
state =
  allow_once(
    %State{
      state: "Published",
      order: 1,
      creator_id: user.id,
      organisation_id: organisation.id,
      flow_id: flow.id
    },
    state: "Published"
  )

# Populate Instance
allow_once(
  %Instance{
    instance_id: "OFFLET0001",
    raw: "Hi John Doe, We offer you the position of Elixir developer",
    serialized: %{
      title: "Offer Letter for Elixir",
      body: "Hi John Doe, We offer you the position of Elixir developer"
    },
    creator_id: user.id,
    content_type_id: content_type.id,
    state_id: state.id
  },
  instance_id: "OFFLET0001"
)

# Populate Counter
allow_once(
  %Counter{
    subject: "ContentType:#{content_type.id}",
    count: 1
  },
  subject: "ContentType:#{content_type.id}"
)

# Populate theme
allow_once(
  %Theme{
    name: "Offer letter theme",
    font: "Malery",
    typescale: %{h1: 10, h2: 8, p: 6},
    creator_id: user.id,
    organisation_id: organisation.id
  },
  font: "Malery"
)

# Populate data template
allow_once(
  %DataTemplate{
    title: "Offer letter tempalate",
    title_template: "Offer Letter for [employee]",
    data: "Hi [employee], we welcome you to our [company]",
    content_type_id: content_type.id,
    creator_id: user.id
  },
  content_type_id: content_type.id
)

# Populate plans
allow_once(
  %Plan{
    name: "Free Trial",
    description: "Free trial where users can try out all the features",
    yearly_amount: 0,
    monthly_amount: 0
  },
  name: "Free Trial"
)

allow_once(
  %Plan{
    name: "Premium",
    description: "Premium plan with premium features only",
    yearly_amount: 0,
    monthly_amount: 0
  },
  name: "Premium"
)

allow_once(
  %Plan{
    name: "Pro",
    description: "Pro plan suitable for enterprises",
    yearly_amount: 0,
    monthly_amount: 0
  },
  name: "Pro"
)

File.stream!("priv/repo/data/super_resources.csv")
|> CSV.decode(headers: ["category", "action"])
|> Enum.each(fn {:ok, x} ->
  function = String.replace_leading(x["action"], ":", "")

  controller =
    x["category"]
    |> String.replace_leading("WraftDocWeb.Api.V1.", "")
    |> String.replace_trailing("Controller", "")
    |> String.downcase()

  comeon_resource(%Resource{
    name: function <> "_" <> controller,
    category: String.to_atom("Elixir." <> x["category"]),
    action: String.to_atom(function)
  })
end)

File.stream!("priv/repo/data/resources.csv")
|> CSV.decode(headers: ["category", "action"])
|> Enum.each(fn {:ok, x} ->
  function = String.replace_leading(x["action"], ":", "")

  controller =
    x["category"]
    |> String.replace_leading("WraftDocWeb.Api.V1.", "")
    |> String.replace_trailing("Controller", "")
    |> String.downcase()

  %{id: resource_id} =
    comeon_resource(%Resource{
      name: function <> "_" <> controller,
      category: String.to_atom("Elixir." <> x["category"]),
      action: String.to_atom(function)
    })

  allow_once(%Permission{role_id: role_admin.id, resource_id: resource_id},
    role_id: role_admin.id,
    resource_id: resource_id
  )
end)

File.stream!("priv/repo/data/user_resources.csv")
|> CSV.decode(headers: ["category", "action"])
|> Enum.each(fn {:ok, x} ->
  function = String.replace_leading(x["action"], ":", "")

  controller =
    x["category"]
    |> String.replace_leading("WraftDocWeb.Api.V1.", "")
    |> String.replace_trailing("Controller", "")
    |> String.downcase()

  %{id: resource_id} =
    comeon_resource(%Resource{
      name: function <> "_" <> controller,
      category: String.to_atom("Elixir." <> x["category"]),
      action: String.to_atom(function)
    })

  allow_once(%Permission{role_id: role_user.id, resource_id: resource_id},
    role_id: role_user.id,
    resource_id: resource_id
  )
end)
