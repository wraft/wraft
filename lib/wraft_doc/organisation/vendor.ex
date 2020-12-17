defmodule WraftDoc.Enterprise.Vendor do
  @moduledoc """
  Vendor is actually the document recipient of a document issuing authority
  ## Example
  * If Company X is sending a proposal to Y the Y is the vendor and x is the issuing authority
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Arc.Ecto.Schema
  alias WraftDoc.Account.User
  import Ecto.Query
  alias __MODULE__
  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: __MODULE__ do
    def actor(vendor), do: "#{vendor.creator_id}"
    def object(vendor), do: "Vendor:#{vendor.id}"

    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

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
