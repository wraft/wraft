defmodule WraftDoc.Repo.Migrations.AddFreeSubscriptionsToExistingOrganisations do
  use Ecto.Migration
  import Ecto.Query

  alias WraftDoc.Billing.Subscription
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  def change do
    execute_up()
  end

  defp execute_up do
    organisations_query =
      from(o in Organisation,
        left_join: s in Subscription,
        on: s.organisation_id == o.id,
        where: is_nil(s.id),
        select: o.id
      )

    organisation_ids = Repo.all(organisations_query)

    for org_id <- organisation_ids do
      Enterprise.create_free_subscription(org_id)
    end
  end
end
