defmodule WraftDoc.CounterParties.VendorContact do
  @moduledoc """
  This module handles vendor contact information.
  Vendor contacts are individuals associated with vendor organizations.
  """
  use WraftDoc.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.CounterParties.Vendor

  @email_regex ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          email: String.t() | nil,
          phone: String.t() | nil,
          job_title: String.t() | nil,
          vendor_id: integer(),
          counter_party_id: integer() | nil,
          creator_id: integer(),
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
    belongs_to(:counter_party, CounterParty)
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
      :counter_party_id,
      :creator_id
    ])
    |> validate_required([:name, :vendor_id, :creator_id])
    |> validate_format(:email, @email_regex, message: "must be a valid email address")
    |> validate_length(:email, max: 255)
    |> validate_length(:phone, max: 50)
    |> validate_length(:job_title, max: 100)
    |> validate_length(:name, max: 255, min: 2)
    |> unique_constraint([:vendor_id, :counter_party_id],
      name: :vendor_contacts_vendor_counter_party_unique,
      message: "is already associated with this vendor"
    )
    |> foreign_key_constraint(:vendor_id)
    |> foreign_key_constraint(:counter_party_id)
    |> foreign_key_constraint(:creator_id)
  end

  @doc """
  Builds a changeset for creating a new vendor contact.
  """
  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end
end
