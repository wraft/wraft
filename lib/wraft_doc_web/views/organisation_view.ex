defmodule WraftDocWeb.Api.V1.OrganisationView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.UserView

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
      logo: organisation |> generate_url()
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
      logo: organisation |> generate_url()
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
      logo: organisation |> generate_url()
    }
  end

  def render("members.json", %{
        members: members,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      members: render_many(members, UserView, "me.json", as: :user),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("invite.json", %{}) do
    %{
      info: "Invited successfully.!"
    }
  end

  defp generate_url(%{logo: logo} = organisation) do
    WraftDocWeb.LogoUploader.url(logo, organisation)
  end
end
