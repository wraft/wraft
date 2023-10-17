defmodule WraftDocWeb.Api.V1.OrganisationView do
  use WraftDocWeb, :view

  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("create.json", %{organisation: organisation}) do
    %{
      id: organisation.id,
      name: organisation.name,
      legal_name: organisation.legal_name,
      address: organisation.address,
      name_of_ceo: organisation.name_of_ceo,
      name_of_cto: organisation.name_of_cto,
      corporate_id: organisation.corporate_id,
      gstin: organisation.gstin,
      email: organisation.email,
      phone: organisation.phone,
      url: organisation.url,
      logo: generate_url(organisation)
    }
  end

  def render("show.json", %{organisation: organisation}) do
    %{
      id: organisation.id,
      name: organisation.name,
      legal_name: organisation.legal_name,
      address: organisation.address,
      name_of_ceo: organisation.name_of_ceo,
      name_of_cto: organisation.name_of_cto,
      corporate_id: organisation.corporate_id,
      gstin: organisation.gstin,
      email: organisation.email,
      phone: organisation.phone,
      url: organisation.url,
      logo: generate_url(organisation)
    }
  end

  def render("organisation.json", %{organisation: organisation}) do
    %{
      id: organisation.id,
      name: organisation.name,
      legal_name: organisation.legal_name,
      address: organisation.address,
      name_of_ceo: organisation.name_of_ceo,
      name_of_cto: organisation.name_of_cto,
      corporate_id: organisation.corporate_id,
      gstin: organisation.gstin,
      email: organisation.email,
      phone: organisation.phone,
      logo: generate_url(organisation)
    }
  end

  def render("org_by_user.json", %{organisation: organisation}) do
    %{
      id: organisation.id,
      name: organisation.name,
      logo: generate_url(organisation)
    }
  end

  def render("remove_user.json", %{}) do
    %{
      info: "User removed from the organisation.!"
    }
  end

  def render("members.json", %{
        members: members,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      members: render_many(members, UserView, "show.json", as: :user),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("index.json", %{
        organisations: organisations,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      organisations:
        render_many(organisations, OrganisationView, "create.json", as: :organisation),
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

  def render("verify_invite_token.json", %{organisation: organisation, email: email}) do
    %{
      organisation: %{
        id: organisation.id,
        name: organisation.name
      },
      email: email
    }
  end

  defp generate_url(%{logo: logo} = organisation) do
    WraftDocWeb.LogoUploader.url({logo, organisation}, signed: true)
  end
end
