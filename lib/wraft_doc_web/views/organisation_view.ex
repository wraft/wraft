defmodule WraftDocWeb.Api.V1.OrganisationView do
  use WraftDocWeb, :view

  alias __MODULE__
  alias WraftDoc.Account.User
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
      members_count: organisation.members_count,
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

  def render("delete.json", %{
        organisation: organisation,
        refresh_token: refresh_token,
        access_token: access_token,
        user: user
      }) do
    %{
      refresh_token: refresh_token,
      access_token: access_token,
      organisation: render_one(organisation, __MODULE__, "organisation.json", as: :organisation),
      user: render_one(user, UserView, "user.json", as: :user)
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
      members: render_many(members, UserView, "member.json", as: :user),
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

  def render("transfer_ownership.json", %{}) do
    %{
      info: "The Ownership of the Organisation has been successfully transferred."
    }
  end

  def render("invite.json", %{}) do
    %{
      info: "Invited successfully.!"
    }
  end

  def render("verify_invite_token.json", %{
        organisation: organisation,
        email: email,
        is_organisation_member: is_organisation_member,
        is_wraft_member: is_wraft_member
      }) do
    %{
      organisation: %{
        id: organisation.id,
        name: organisation.name
      },
      email: email,
      is_organisation_member: organisation_member?(is_organisation_member),
      is_wraft_member: wraft_member?(is_wraft_member)
    }
  end

  def render("invite_token_status.json", %{email: email, isNewUser: isNewUser}) do
    %{
      email: email,
      isNewUser: isNewUser
    }
  end

  def render("permissions.json", %{permissions: permissions}) do
    %{
      permissions: permissions
    }
  end

  def render("invited_users.json", %{invited_users: invited_users}) do
    render_many(invited_users, __MODULE__, "invited_user.json", as: :invited_user)
  end

  def render("invited_user.json", %{invited_user: invited_user}) do
    %{
      id: invited_user.id,
      email: invited_user.email,
      status: invited_user.status
    }
  end

  defp organisation_member?({:error, :already_member}), do: true
  defp organisation_member?(:ok), do: false

  defp wraft_member?(%User{}), do: true
  defp wraft_member?(nil), do: false

  defp generate_url(%{logo: logo} = organisation) do
    WraftDocWeb.LogoUploader.url({logo, organisation}, signed: true)
  end
end
