defmodule WraftDoc.Enterprise.Vendor do
  @moduledoc """
  This module handles vendor information and validations.
  Vendors are organizations that provide goods/services and are standalone entities
  not bound to specific documents.
  """
  use WraftDoc.Schema
  import Waffle.Ecto.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          email: String.t() | nil,
          phone: String.t() | nil,
          address: String.t() | nil,
          city: String.t() | nil,
          country: String.t() | nil,
          gstin: String.t() | nil,
          reg_no: String.t() | nil,
          website: String.t() | nil,
          logo: String.t() | nil,
          contact_person: String.t() | nil,
          creator_id: integer(),
          organisation_id: integer(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "vendors" do
    field(:name, :string)
    field(:email, :string)
    field(:phone, :string)
    field(:address, :string)
    field(:city, :string)
    field(:country, :string)
    field(:gstin, :string)
    field(:reg_no, :string)
    field(:website, :string)
    field(:logo, WraftDocWeb.LogoUploader.Type)
    field(:contact_person, :string)

    # Associations
    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)

    has_many(:vendor_contacts, WraftDoc.Enterprise.VendorContact)

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
      :email,
      :phone,
      :address,
      :city,
      :country,
      :gstin,
      :reg_no,
      :website,
      :contact_person,
      :creator_id,
      :organisation_id
    ])
    |> cast_attachments(attrs, [:logo])
    |> validate_required([:name, :creator_id, :organisation_id])
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/,
      message: "must be a valid email address"
    )
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 50)
    |> validate_length(:name, max: 255, min: 2)
    |> unique_constraint([:organisation_id, :name],
      name: :vendors_organisation_id_name_index,
      message: "Vendor with this name already exists in the organization"
    )
    |> foreign_key_constraint(:organisation_id,
      name: :vendors_organisation_id_fkey,
      message: "Organization does not exist"
    )
    |> foreign_key_constraint(:creator_id,
      name: :vendors_creator_id_fkey,
      message: "Creator does not exist"
    )
  end

  @doc """
  Builds a changeset for updating a vendor with validation rules.
  """
  @spec update_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(vendor, attrs \\ %{}) do
    vendor
    |> cast(attrs, [
      :name,
      :email,
      :phone,
      :address,
      :city,
      :country,
      :gstin,
      :reg_no,
      :website,
      :contact_person,
      :creator_id,
      :organisation_id
    ])
    |> cast_attachments(attrs, [:logo])
    |> validate_required([:name, :creator_id, :organisation_id])
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/,
      message: "must be a valid email address"
    )
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 50)
    |> validate_length(:name, max: 255, min: 2)
    |> unique_constraint([:organisation_id, :name],
      name: :vendors_organisation_id_name_index,
      message: "Vendor with this name already exists in the organization"
    )
    |> foreign_key_constraint(:organisation_id,
      name: :vendors_organisation_id_fkey,
      message: "Organization does not exist"
    )
    |> foreign_key_constraint(:creator_id,
      name: :vendors_creator_id_fkey,
      message: "Creator does not exist"
    )
  end
end
