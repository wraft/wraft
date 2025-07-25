defmodule WraftDoc.Vendors do
  @moduledoc """
  The Vendors context.
  """
  import Ecto.Query
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo
  alias WraftDoc.Vendors.Vendor
  alias WraftDoc.Vendors.VendorContact

  @doc """
  Create a vendor under organisations
  ##Parameters
  - `current_user` - an User struct
  - `params` - a map countains vendor parameters

  """
  @spec create_vendor(User.t(), map) :: Vendor.t() | {:error, Ecto.Changeset.t()}
  def create_vendor(%User{current_org_id: org_id} = current_user, params) do
    params = Map.merge(params, %{"organisation_id" => org_id, "creator_id" => current_user.id})

    %Vendor{}
    |> Vendor.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, vendor} ->
        Repo.preload(vendor, creator: [:profile])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Retunrs vendor by id and organisation
  ##Parameters
  -`uuid`- UUID of vendor
  -`organisation`- Organisation struct

  """
  @spec get_vendor(User.t(), Ecto.UUID.t()) :: Vendor.t()
  def get_vendor(%User{current_org_id: org_id}, id) do
    query = from(v in Vendor, where: v.id == ^id and v.organisation_id == ^org_id)

    case Repo.one(query) do
      %Vendor{} = vendor -> vendor
      _ -> {:error, :invalid_id, "Vendor"}
    end
  end

  def get_vendor(_, _), do: nil

  @spec show_vendor(Ecto.UUID.t(), User.t()) :: Vendor.t()
  def show_vendor(id, user) do
    with %Vendor{} = vendor <- get_vendor(user, id) do
      Repo.preload(vendor, creator: [:profile])
    end
  end

  @doc """
  To update vendor details and attach logo file

  ## Parameters
  -`vendor`- a Vendor struct
  -`params`- a map contains vendor fields
  """
  def update_vendor(vendor, params) do
    vendor
    |> Vendor.update_changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, vendor} ->
        Repo.preload(vendor, creator: [:profile])
    end
  end

  @doc """
  Deletes vendor data
  ##Parameters
  -`vendor`- a Vendor struct
  """
  @spec delete_vendor(Vendor.t()) :: Vendor.t()
  def delete_vendor(%Vendor{} = vendor), do: Repo.delete(vendor)

  @doc """
  Lists all vendors under an organisation
  -`organisation`- an Organisation struct
  -`params` - a map contains params for pagination and search query
  """
  @spec vendor_index(User.t(), map()) :: Scrivener.Paginater.t()
  def vendor_index(%User{current_org_id: organisation_id}, params) do
    query =
      Vendor
      |> where([v], v.organisation_id == ^organisation_id)
      |> apply_search_filter(params)

    Repo.paginate(query, params)
  end

  def vendor_index(_, _), do: nil

  # Private function to apply search filter based on query parameter
  defp apply_search_filter(query, %{"query" => search_term})
       when is_binary(search_term) and search_term != "" do
    search_pattern = "%#{search_term}%"

    where(query, [v], ilike(v.name, ^search_pattern) or ilike(v.email, ^search_pattern))
  end

  defp apply_search_filter(query, _params), do: query

  @doc """
  Create a vendor contact
  """
  @spec create_vendor_contact(User.t(), map) :: VendorContact.t() | {:error, Ecto.Changeset.t()}
  def create_vendor_contact(%User{current_org_id: _org_id} = current_user, params) do
    params = Map.merge(params, %{"creator_id" => current_user.id})

    %VendorContact{}
    |> VendorContact.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, vendor_contact} ->
        Repo.preload(vendor_contact, [:vendor, :creator])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Get vendor contact by id
  """
  @spec get_vendor_contact(User.t(), Ecto.UUID.t()) :: VendorContact.t() | {:error, :invalid_id}
  def get_vendor_contact(%User{current_org_id: org_id}, id) do
    VendorContact
    |> join(:inner, [vc], v in Vendor, on: vc.vendor_id == v.id)
    |> where([vc, v], vc.id == ^id and v.organisation_id == ^org_id)
    |> Repo.one()
    |> case do
      %VendorContact{} = vendor_contact -> vendor_contact
      _ -> {:error, :invalid_id}
    end
  end

  @doc """
  Update vendor contact
  """
  @spec update_vendor_contact(VendorContact.t(), map) ::
          {:ok, VendorContact.t()} | {:error, Ecto.Changeset.t()}
  def update_vendor_contact(vendor_contact, params) do
    vendor_contact
    |> VendorContact.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, vendor_contact} ->
        {:ok, Repo.preload(vendor_contact, [:vendor, :creator])}

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete vendor contact
  """
  @spec delete_vendor_contact(VendorContact.t()) ::
          {:ok, VendorContact.t()} | {:error, Ecto.Changeset.t()}
  def delete_vendor_contact(%VendorContact{} = vendor_contact), do: Repo.delete(vendor_contact)

  @doc """
  List vendor contacts for a vendor
  """
  @spec vendor_contacts_index(User.t(), Ecto.UUID.t(), map) :: Scrivener.Page.t()
  def vendor_contacts_index(%User{current_org_id: org_id}, vendor_id, params) do
    VendorContact
    |> join(:inner, [vc], v in Vendor, on: vc.vendor_id == v.id)
    |> where([vc, v], v.id == ^vendor_id and v.organisation_id == ^org_id)
    |> preload([vc, v], [:vendor, :creator])
    |> Repo.paginate(params)
  end

  @doc """
  Get vendor statistics for a specific vendor.
  Returns a map containing vendor-related statistics.
  """
  @spec get_vendor_stats(Vendor.t()) :: map()
  def get_vendor_stats(%Vendor{id: vendor_id, organisation_id: _org_id}) do
    # Get total documents connected to this vendor
    total_documents =
      Instance
      |> where([i], i.vendor_id == ^vendor_id)
      |> select([i], count(i.id))
      |> Repo.one()

    # Get pending approvals for documents connected to this vendor
    # Based on approval_status field in Instance table
    pending_approvals =
      Instance
      |> where([i], i.vendor_id == ^vendor_id and i.approval_status == false)
      |> select([i], count(i.id))
      |> Repo.one()

    # Get total contract value for documents with contract metadata
    # Contract value is stored in meta field as per contract_meta.ex
    total_contract_value =
      Instance
      |> where(
        [i],
        i.vendor_id == ^vendor_id and not is_nil(fragment("? -> 'contract_value'", i.meta))
      )
      |> select(
        [i],
        coalesce(sum(fragment("CAST(? ->> 'contract_value' AS DECIMAL)", i.meta)), 0)
      )
      |> Repo.one()

    # Get total vendor contacts for this vendor
    # Based on vendor_contacts table relationship
    total_contacts =
      VendorContact
      |> where([contact], contact.vendor_id == ^vendor_id)
      |> select([contact], count(contact.id))
      |> Repo.one()

    # Get documents added this month (not vendors, but documents connected to vendors)
    # This represents new document activity for vendors this month
    start_of_month = Date.beginning_of_month(Date.utc_today())
    start_of_month_datetime = DateTime.new!(start_of_month, ~T[00:00:00])

    new_this_month =
      Instance
      |> where([i], i.vendor_id == ^vendor_id and i.inserted_at >= ^start_of_month_datetime)
      |> select([i], count(i.id))
      |> Repo.one()

    %{
      total_documents: total_documents || 0,
      pending_approvals: pending_approvals || 0,
      total_contract_value: total_contract_value || Decimal.new(0),
      total_contacts: total_contacts || 0,
      new_this_month: new_this_month || 0
    }
  end
end
