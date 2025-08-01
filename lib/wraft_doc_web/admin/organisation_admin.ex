defmodule WraftDocWeb.OrganisationAdmin do
  @moduledoc """
  Admin panel for organisation
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

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
      inserted_at: %{name: "Created At", value: fn x -> x.inserted_at end},
      updated_at: %{name: "Updated At", value: fn x -> x.updated_at end},
      deleted_at: %{name: "Soft Deleted", value: fn x -> deleted_at(x) end}
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

  def ordering(_schema), do: [desc: :inserted_at]

  def custom_index_query(_conn, _schema, query) do
    from(q in query,
      where: q.name != "Personal",
      preload: [:users_organisations, :modified_by]
    )
  end

  def delete(conn, %{data: %{id: org_id} = organisation} = _changeset) do
    admin_id = conn.assigns.admin_session.id

    Multi.new()
    |> Multi.update_all(
      :soft_delete_user_organisations,
      from(uo in UserOrganisation, where: uo.organisation_id == ^org_id),
      set: [deleted_at: DateTime.utc_now()]
    )
    |> Multi.update(
      :update_organisation,
      Organisation.changeset(organisation, %{modified_by_id: admin_id})
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{update_organisation: organisation}} ->
        {:ok, organisation}

      {:error, _, reason, _} ->
        {:error, reason}
    end
  end

  defp deleted_at(%Organisation{users_organisations: [%UserOrganisation{deleted_at: nil}]}),
    do: false

  defp deleted_at(%Organisation{
         users_organisations: [%UserOrganisation{deleted_at: _deleted_at}]
       }),
       do: true

  defp deleted_at(_), do: ""
end
