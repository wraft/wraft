defmodule WraftDoc.Kaffy.Config do
  @moduledoc """
  Config admin panel
  """

  alias WraftDoc.Enterprise

  def create_resources(_conn) do
    [
      account: [
        name: "Account",
        resources: [
          user: [schema: WraftDoc.Account.User, admin: WraftDocWeb.UserAdmin],
          user_role: [schema: WraftDoc.Account.UserRole, admin: WraftDocWeb.UserRoleAdmin]
        ]
      ],
      internal_user: [
        name: "Internal User",
        resources: [
          internal_user: [
            schema: WraftDoc.InternalUsers.InternalUser,
            admin: WraftDocWeb.InternalUserAdmin
          ]
        ]
      ],
      enterprise: [
        name: "Enterprise",
        resources: enterprise_resources()
      ],
      waiting_list: [
        name: "Waiting List",
        resources: [
          waiting_list: [
            schema: WraftDoc.WaitingLists.WaitingList,
            admin: WraftDocWeb.WaitingListAdmin
          ]
        ]
      ],
      custom: [
        name: "Custom",
        resources: [
          field_type: [
            schema: WraftDoc.Fields.FieldType,
            admin: WraftDocWeb.FieldTypeAdmin
          ],
          template_asset: [
            schema: WraftDoc.TemplateAssets.TemplateAsset,
            admin: WraftDocWeb.TemplateAssets.TemplateAssetAdmin
          ]
        ]
      ]
    ]
  end

  defp enterprise_resources do
    resourses = [
      organisation: [
        schema: WraftDoc.Enterprise.Organisation,
        admin: WraftDocWeb.OrganisationAdmin
      ]
    ]

    case Enterprise.self_hosted?() do
      false ->
        resourses ++
          [
            plan: [
              schema: WraftDoc.Enterprise.Plan,
              admin: WraftDocWeb.PlanAdmin
            ],
            enterprise_plan: [
              schema: WraftDoc.Enterprise.Plan,
              admin: WraftDocWeb.EnterprisePlanAdmin
            ],
            coupon: [
              schema: WraftDoc.Billing.Coupon,
              admin: WraftDocWeb.CouponAdmin
            ]
          ]

      true ->
        resourses
    end
  end
end
