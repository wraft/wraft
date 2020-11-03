defmodule WraftDoc.Enterprise.Vendor do
  @moduledoc """
  Vendor is actually the document recipient of a document issuing authority
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Arc.Ecto.Schema

  alias __MODULE__

  schema "vendor" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string)
    field(:email, :string)
    field(:phone, :string)
    field(:address, :string)
    field(:gstin, :string)
    field(:reg_no, :string)
    field(:logo, WraftDocWeb.LogoUploader.Type)
    field(:contact_person, :string)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%Vendor{} = vendor, attrs \\ %{}) do
    vendor
    |> cast(attrs, [
      :name,
      :email,
      :phone,
      :address,
      :gstin,
      :reg_no,
      :contact_person,
      :organisation_id,
      :creator_id
    ])
    |> validate_required([
      :name,
      :email,
      :phone,
      :address,
      :gstin,
      :reg_no,
      :organisation_id,
      :creator_id
    ])
  end

  def update_changeset(%Vendor{} = vendor, attrs \\ %{}) do
    vendor
    |> cast(attrs, [
      :name,
      :email,
      :phone,
      :address,
      :gstin,
      :reg_no,
      :contact_person,
      :organisation_id,
      :logo,
      :creator_id
    ])
    |> validate_required([
      :name,
      :email,
      :phone,
      :address,
      :gstin,
      :reg_no
    ])
    |> cast_attachments(attrs, [:logo])
  end
end
