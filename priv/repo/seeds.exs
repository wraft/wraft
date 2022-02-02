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
  Document.ContentTypeField,
  Document.DataTemplate,
  Document.FieldType,
  Document.Instance,
  Document.Theme,
  Enterprise.ApprovalSystem,
  Enterprise.Organisation,
  Enterprise.Flow,
  Enterprise.Flow.State,
  Enterprise.Plan,
  Enterprise.Membership,
  Enterprise.Vendor,
  Document.FieldType,
  Document.ContentTypeField,
  Document.Counter,
  Document.DataTemplate,
  Document.Instance.Version,
  Repo
}

import WraftDoc.SeedGate

# Populate database with roles

%{id: role_id} = allow_once(%Role{name: "super_admin"}, name: "super_admin")

role_user = allow_once(%Role{name: "user"}, name: "user")
role_admin = allow_once(%Role{name: "admin"}, name: "admin")

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

aurut =
  allow_once(
    %Organisation{
      name: "Aurut",
      legal_name: "Aurut",
      address: "#24, Caravel Building",
      name_of_ceo: "Muneef Hameed",
      name_of_cto: "Salsabeel K",
      email: "admin@aurut.com"
    },
    email: "admin@aurut.com"
  )

aurut_admin =
  comeon_user(%{
    name: "Aurut Admin",
    email: "admin@aurut.com",
    email_verify: true,
    password: "Admin@Aurut",
    organisation_id: aurut.id
  })

user =
  comeon_user(%{
    name: "Super Admin",
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

allow_once(%UserRole{user_id: aurut_admin.id, role_id: role_admin.id},
  user_id: aurut_admin.id,
  role_id: role_admin.id
)

allow_once(%UserRole{user_id: normal_user.id, role_id: role_user.id},
  user_id: normal_user.id,
  role_id: role_user.id
)

allow_once(%Profile{name: "Super Admin", user_id: user.id}, name: "Super Admin")

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

draft =
  allow_once(
    %State{
      state: "Draft",
      order: 1,
      creator_id: user.id,
      organisation_id: organisation.id,
      flow_id: flow.id
    },
    state: "Draft"
  )

# Populate State
review =
  allow_once(
    %State{
      state: "Review",
      order: 2,
      creator_id: user.id,
      organisation_id: organisation.id,
      flow_id: flow.id
    },
    state: "Review"
  )

published =
  allow_once(
    %State{
      state: "Published",
      order: 3,
      creator_id: user.id,
      organisation_id: organisation.id,
      flow_id: flow.id
    },
    state: "Published"
  )

allow_once(
  %ApprovalSystem{
    pre_state_id: draft.id,
    post_state_id: review.id,
    flow_id: flow.id,
    approver_id: user.id,
    creator_id: user.id
  },
  pre_state_id: draft.id
)

allow_once(
  %ApprovalSystem{
    pre_state_id: review.id,
    post_state_id: published.id,
    flow_id: flow.id,
    approver_id: user.id,
    creator_id: user.id
  },
  pre_state_id: published.id
)

allow_once(
  %Vendor{
    name: "System 76",
    email: "system76tes@gmail.com",
    phone: "9826226226",
    address: "DG, Roose agusting-60006 california",
    gstin: "222asdfsd6",
    reg_no: "32dsfs",
    contact_person: "Sadique",
    organisation_id: organisation.id,
    creator_id: user.id
  },
  email: "system76tes@gmail.com"
)

# Populate Instance
instance =
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
      state_id: draft.id
    },
    instance_id: "OFFLET0001"
  )

# Populate versions
allow_once(
  %Version{
    version_number: 1,
    raw: instance.raw,
    serialized: instance.serialized,
    author_id: user.id,
    content_id: instance.id
  },
  content_id: instance.id,
  version_number: 1
)

allow_once(
  %Version{
    version_number: 2,
    raw: "Hi John Doe, We offer you the position of Elixir Backend developer",
    serialized: %{
      title: "Offer Letter for Elixir",
      body: "Hi John Doe, We offer you the position of Elixir Backend developer"
    },
    author_id: user.id,
    content_id: instance.id,
    naration: "Version 0.2"
  },
  content_id: instance.id,
  version_number: 2
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

plan =
  allow_once(
    %Plan{
      name: "Pro",
      description: "Pro plan suitable for enterprises",
      yearly_amount: 0,
      monthly_amount: 0
    },
    name: "Pro"
  )

allow_once(%Membership{is_expired: false, organisation_id: organisation.id},
  organisation_id: organisation.id
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
    action: String.to_atom(function),
    label: controller
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
      action: String.to_atom(function),
      label: controller
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
      action: String.to_atom(function),
      label: controller
    })

  allow_once(%Permission{role_id: role_user.id, resource_id: resource_id},
    role_id: role_user.id,
    resource_id: resource_id
  )
end)

File.stream!("priv/repo/data/layout.csv")
|> CSV.decode(headers: ["name", "description", "width", "height", "unit", "slug"])
|> Enum.each(fn {:ok, x} ->
  allow_once(
    %Layout{
      name: x["name"],
      description: x["description"],
      width: String.to_float(x["width"]),
      height: String.to_float(x["height"]),
      unit: x["unit"],
      slug: x["slug"],
      creator_id: user.id,
      organisation_id: organisation.id
    },
    name: x["name"]
  )
end)

File.stream!("priv/repo/data/content_type.csv")
|> CSV.decode(headers: ["name", "color", "description", "prefix", "layout"])
|> Enum.each(fn {:ok, x} ->
  layout = Repo.get_by(Layout, name: x["layout"])

  allow_once(
    %ContentType{
      name: x["name"],
      color: x["color"],
      description: x["description"],
      prefix: x["prefix"],
      layout_id: layout.id,
      organisation_id: organisation.id,
      creator_id: user.id,
      flow_id: flow.id
    },
    name: x["name"]
  )
end)

File.stream!("priv/repo/data/data_template.csv")
|> CSV.decode(headers: ["title", "content_type", "title_template", "data", "serialized"])
|> Enum.each(fn {:ok, x} ->
  data = File.read!("priv/repo/data/#{x["data"]}")
  content_type = Repo.get_by(ContentType, name: x["content_type"])

  serialized =
    with {:ok, body} <- File.read("priv/repo/data/#{x["serialized"]}"),
         {:ok, json} <- Jason.decode(body) do
      json
    end

  allow_once(
    %DataTemplate{
      title: x["title"],
      content_type_id: content_type.id,
      title_template: x["title_template"],
      data: data,
      serialized: serialized
    },
    title: x["title"]
  )
end)

File.stream!("priv/repo/data/fields.csv")
|> CSV.decode(headers: ["name", "type", "content_type"])
|> Enum.each(fn {:ok, x} ->
  content_type = Repo.get_by(ContentType, name: x["content_type"])
  type = allow_once(%FieldType{name: x["type"]}, name: x["type"])

  allow_once(
    %ContentTypeField{name: x["name"], field_type_id: type.id, content_type_id: content_type.id},
    name: x["name"]
  )
end)
