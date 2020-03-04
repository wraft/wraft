defmodule OrganisationAssoications do
  import Ecto.Query

  alias WraftDoc.{
    Repo,
    Account.User,
    Account.Role,
    Enterprise.Organisation,
    Document.Layout,
    Document.ContentType,
    Enterprise.Flow
  }

  def create_organisation() do
    %Organisation{name: "Functionary Labs Pvt Ltd."} |> Repo.insert!()
  end

  def organisation_id() do
    from(r in Organisation, where: r.name == "Functionary Labs Pvt Ltd.", select: r.id)
    |> Repo.one()
  end

  def user_and_organisation() do
    from(u in User, join: r in Role, where: r.name == "user" and u.role_id == r.id)
    |> Repo.update_all(set: [organisation_id: organisation_id()])
  end

  def layout_and_organisation() do
    Repo.update_all(Layout, set: [organisation_id: organisation_id()])
  end

  def content_type_and_organisation() do
    Repo.update_all(ContentType, set: [organisation_id: organisation_id()])
  end

  def flow_and_organisation() do
    Repo.update_all(Flow, set: [organisation_id: organisation_id()])
  end
end

OrganisationAssoications.create_organisation()
OrganisationAssoications.user_and_organisation()
OrganisationAssoications.layout_and_organisation()
OrganisationAssoications.content_type_and_organisation()
OrganisationAssoications.flow_and_organisation()
