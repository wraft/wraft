defmodule WraftDoc.CounterParties.Vendor do
  @moduledoc """
  This module handles vendor information and validations.
  Vendors are organizations that provide goods/services and can be associated with documents.
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise.Organisation

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          gstin: String.t() | nil,
          website: String.t() | nil,
          address: String.t() | nil,
          city: String.t() | nil,
          country: String.t() | nil,
          creator_id: integer(),
          organisation_id: integer(),
          content_id: integer() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "vendors" do
    field(:name, :string)
    field(:gstin, :string)
    field(:website, :string)
    field(:address, :string)
    field(:city, :string)
    field(:country, :string)

    # Associations
    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)
    belongs_to(:content, Instance)

    has_many(:vendor_contacts, WraftDoc.CounterParties.VendorContact)

    timestamps()
  end

  @doc """
  Builds a changeset for a vendor with validation rules.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(vendor, attrs) do
    vendor
    |> cast(attrs, [
      :name,
      :gstin,
      :website,
      :address,
      :city,
      :country,
      :creator_id,
      :organisation_id,
      :content_id
    ])
    |> validate_required([:name, :creator_id, :organisation_id])
    |> unique_constraint(:gstin,
      name: :vendors_gstin_unique,
      message: "Vendor with this GSTIN already exists"
    )
    |> unique_constraint([:organisation_id, :name],
      name: :vendors_organisation_id_name_unique,
      message: "Vendor with this name already exists in the organization"
    )
    |> unique_constraint(:creator_id,
      name: :vendors_creator_id_organisation_id_index,
      message: "Vendor already exists"
    )
    |> unique_constraint(:organisation_id,
      name: :vendors_organisation_id_organisation_id_index,
      message: "Vendor already exists"
    )
  end
end
