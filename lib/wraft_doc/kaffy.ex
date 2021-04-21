defmodule WraftDoc.Kaffy.Config do
  @moduledoc """
  Config admin panel
  """
  def create_resources(_conn) do
    [
      account: [
        name: "Account",
        resources: [
          user: [schema: WraftDoc.Account.User, admin: WraftDocWeb.UserAdmin],
          user_role: [schema: WraftDoc.Account.UserRole, admin: WraftDocWeb.UserRoleAdmin]
        ]
      ],
      enterprise: [
        name: "Enterprise",
        resources: [
          organisation: [
            schema: WraftDoc.Enterprise.Organisation,
            admin: WraftDocWeb.OrganisationAdmin
          ],
          membership: [schema: WraftDoc.Enterprise.Membership]
        ]
      ],
      authorization: [
        name: "Authorisation",
        resources: [
          conroller: [
            schema: WraftDoc.Authorization.Resource,
            admin: WraftDocWeb.ResourceAdmin
          ]
        ]
      ]
    ]
  end
end
