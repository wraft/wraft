defmodule WraftDocWeb.OrganisationAdmin do
  @moduledoc """
  Admin panel for organisation
  """
  alias WraftDoc.Enterprise

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      legal_name: %{name: "Legal name", value: fn x -> x.legal_name end},
      address: %{name: "Address", value: fn x -> x.address end},
      name_of_ceo: %{name: "Name of CEO", value: fn x -> x.name_of_ceo end},
      name_of_cto: %{name: "Name of CTO", value: fn x -> x.name_of_cto end},
      gstin: %{name: "GSTIN", value: fn x -> x.gstin end},
      corporate_id: %{name: "Corporate id", value: fn x -> x.corporate_id end},
      phone: %{name: "Phone", value: fn x -> x.phone end},
      email: %{email: "Email", value: fn x -> x.email end}
    ]
  end

  def form_fields(_) do
    [
      name: %{label: "Name"},
      legal_name: %{label: "Legal name"},
      address: %{label: "Address", type: :textarea},
      name_of_ceo: %{label: "Name of CEO"},
      name_of_cto: %{label: "Name of CTO"},
      gstin: %{label: "GSTIN"},
      corporate_id: %{label: "Corporate id"},
      phone: %{label: "Phone"},
      email: %{label: "Email"}
    ]
  end

  def after_insert(conn, organisation) do
    user = conn.assigns[:current_user]
    Enterprise.invite_team_member(user, organisation, organisation.email, "admin")
  end

  def after_update(conn, organisation) do
    user = conn.assigns[:current_user]
    Enterprise.invite_team_member(user, organisation, organisation.email, "admin")
  end
end
