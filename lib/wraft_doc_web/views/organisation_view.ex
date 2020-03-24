defmodule WraftDocWeb.Api.V1.OrganisationView do
  use WraftDocWeb, :view

  def render("create.json", %{organisation: organisation}) do
    %{
      id: organisation.uuid,
      name: organisation.name,
      legal_name: organisation.legal_name,
      address: organisation.address,
      name_of_ceo: organisation.name_of_ceo,
      name_of_cto: organisation.name_of_cto,
      corporate_id: organisation.corporate_id,
      gstin: organisation.gstin,
      email: organisation.email,
      phone: organisation.phone,
      logo: organisation.logo
    }
  end

  def render("show.json", %{organisation: organisation}) do
    %{
      id: organisation.uuid,
      name: organisation.name,
      legal_name: organisation.legal_name,
      address: organisation.address,
      name_of_ceo: organisation.name_of_ceo,
      name_of_cto: organisation.name_of_cto,
      corporate_id: organisation.corporate_id,
      gstin: organisation.gstin,
      email: organisation.email,
      phone: organisation.phone,
      logo: organisation.logo
    }
  end

  def render("organisation.json", %{organisation: organisation}) do
    %{
      id: organisation.uuid,
      name: organisation.name,
      legal_name: organisation.legal_name,
      address: organisation.address,
      name_of_ceo: organisation.name_of_ceo,
      name_of_cto: organisation.name_of_cto,
      corporate_id: organisation.corporate_id,
      gstin: organisation.gstin,
      email: organisation.email,
      phone: organisation.phone,
      logo: organisation.logo
    }
  end

  def render("invite.json", %{}) do
    %{
      info: "Invited successfully.!"
    }
  end
end
