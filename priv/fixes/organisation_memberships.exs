defmodule OrganisationMembershio do
  import Ecto
  import Ecto.Query
  alias WraftDoc.{Enterprise.Membership, Enterprise.Organisation, Enterprise.Plan, Repo}
  @trial_plan_name "Free Trial"
  @trial_duration 14

  def get_organisations_without_membership() do
    query = from(o in Organisation,
      left_join: m in Membership,
      on: m.organisation_id == o.id,
      where: is_nil(m.organisation_id)
    )
    query
    |> Repo.all()
    |> Enum.each(fn x -> create_membership(x) end)
  end

  defp create_membership(organisation) do
    plan = Repo.get_by(Plan, name: @trial_plan_name)
    start_date = Timex.now()
    end_date = start_date |> Timex.shift(days: @trial_duration)
    params = %{start_date: start_date, end_date: end_date, plan_duration: @trial_duration}

    plan
    |> build_assoc(:memberships, organisation_id: organisation.id)
    |> Membership.changeset(params)
    |> Repo.insert!()
  end
end

OrganisationMembershio.get_organisations_without_membership()
