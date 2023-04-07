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
          membership: [schema: WraftDoc.Enterprise.Membership, admin: WraftDocWeb.MembershipAdmin],
          plan: [schema: WraftDoc.Enterprise.Plan, admin: WraftDocWeb.PlanAdmin]
        ]
      ],
      authorization: [
        name: "Authorisation",
        resources: [
          conroller: [
            schema: WraftDoc.Authorization.Resource
          ]
        ]
      ],
      waiting_list: [
        name: "Waiting List",
        resources: [
          waiting_list: [
            schema: WraftDoc.WaitingLists.WaitingList,
            admin: WraftDocWeb.WaitingListAdmin
          ]
        ]
      ]
    ]
  end
end
