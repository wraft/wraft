defmodule WraftDocWeb.OrganisationAdmin do
  @moduledoc """
  Admin panel for organisation
  """
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo
  import Ecto.Query

  def widgets(_schema, _conn) do
    query = from(u in Organisation, select: count(u.id))
    user_count = Repo.one(query)

    [
      %{
        icon: "city",
        type: "tidbit",
        title: "Total Organisation",
        content: user_count,
        order: 3,
        width: 3
      }
    ]
  end

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      email: %{email: "Email", value: fn x -> x.email end},
      deleted_at: %{name: "Deleted", value: fn x -> deleted_at(x) end},
      inserted_at: %{name: "Created At", value: fn x -> x.inserted_at end},
      updated_at: %{name: "Updated At", value: fn x -> x.updated_at end}
      # legal_name: %{name: "Legal name", value: fn x -> x.legal_name end},
      # address: %{name: "Address", value: fn x -> x.address end},
      # name_of_ceo: %{name: "Name of CEO", value: fn x -> x.name_of_ceo end},
      # name_of_cto: %{name: "Name of CTO", value: fn x -> x.name_of_cto end},
      # gstin: %{name: "GSTIN", value: fn x -> x.gstin end},
      # corporate_id: %{name: "Corporate id", value: fn x -> x.corporate_id end},
      # phone: %{name: "Phone", value: fn x -> x.phone end}
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

  def ordering(_schema) do
    # order by created_at
    [desc: :inserted_at]
  end

  def custom_index_query(_conn, _schema, query) do
    from(q in query, preload: [:users_organisations])
  end

  defp deleted_at(%Organisation{users_organisations: [%UserOrganisation{deleted_at: nil}]}) do
    false
  end

  defp deleted_at(%Organisation{
         users_organisations: [%UserOrganisation{deleted_at: _deleted_at}]
       }) do
    true
  end

  defp deleted_at(_), do: ""
end
