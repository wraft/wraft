defmodule OrganisationAssoications do
  import Ecto.Query

  alias WraftDoc.{
    Account.Role,
    Account.User,
    Document.ContentType,
    Document.Layout,
    Enterprise.Flow,
    Enterprise.Organisation,
    Repo
  }

  def create_organisation do
    Repo.insert!(%Organisation{name: "Functionary Labs Pvt Ltd."})
  end

  def organisation_id do
    query = from(r in Organisation, where: r.name == "Functionary Labs Pvt Ltd.", select: r.id)
    Repo.one(query)
  end

  def user_and_organisation do
    query = from(u in User, join: r in Role, where: r.name == "user" and u.role_id == r.id)
    Repo.update_all(query, set: [organisation_id: organisation_id()])
  end

  def layout_and_organisation do
    Repo.update_all(Layout, set: [organisation_id: organisation_id()])
  end

  def content_type_and_organisation do
    Repo.update_all(ContentType, set: [organisation_id: organisation_id()])
  end

  def flow_and_organisation do
    Repo.update_all(Flow, set: [organisation_id: organisation_id()])
  end
end

OrganisationAssoications.create_organisation()
OrganisationAssoications.user_and_organisation()
OrganisationAssoications.layout_and_organisation()
OrganisationAssoications.content_type_and_organisation()
OrganisationAssoications.flow_and_organisation()
