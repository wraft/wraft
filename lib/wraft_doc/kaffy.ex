defmodule WraftDoc.Kaffy.Config do
  @moduledoc """
  Config admin panel
  """
  def create_resources(_conn) do
    [
      account: [
        name: "Account",
        resources: [
          user: [schema: WraftDoc.Account.User, admin: WraftDoc.Account.UserAdmin]
        ]
      ],
      enterprise: [
        name: "Enterprise",
        resources: [
          organisation: [schema: WraftDoc.Enterprise.Organisation]
        ]
      ]
    ]
  end
end
