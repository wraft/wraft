defmodule WraftDoc.Organisation.VendorContact do
  @moduledoc """
  This module handles vendor contact information.
  Vendor contacts are individuals associated with vendor organizations.
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Vendor

  @email_regex ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          email: String.t() | nil,
          phone: String.t() | nil,
          job_title: String.t() | nil,
          vendor_id: integer(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "vendor_contacts" do
    field(:name, :string)
    field(:email, :string)
    field(:phone, :string)
    field(:job_title, :string)

    # Associations
    belongs_to(:vendor, Vendor)
    belongs_to(:creator, User)

    timestamps()
  end

  @doc """
  Builds a changeset for a vendor contact with validation rules.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = vendor_contact, attrs \\ %{}) do
    vendor_contact
    |> cast(attrs, [
      :name,
      :email,
      :phone,
      :job_title,
      :vendor_id,
      :creator_id
    ])
    |> validate_required([:name, :vendor_id])
    |> validate_format(:email, @email_regex, message: "must be a valid email address")
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 50)
    |> validate_length(:job_title, max: 100)
    |> validate_length(:name, max: 255, min: 2)
    |> foreign_key_constraint(:vendor_id,
      name: :vendor_contacts_vendor_id_fkey,
      message: "Vendor does not exist"
    )
    |> foreign_key_constraint(:creator_id,
      name: :vendor_contacts_creator_id_fkey,
      message: "Creator does not exist"
    )
  end
end
