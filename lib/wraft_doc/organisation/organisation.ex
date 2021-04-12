defmodule WraftDoc.Enterprise.Organisation do
  @moduledoc """
    The organisation model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  use Arc.Ecto.Schema
  alias WraftDoc.Enterprise.Organisation
  @derive {Jason.Encoder, only: [:name]}
  schema "organisation" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:legal_name, :string)
    field(:address, :string)
    field(:name_of_ceo, :string)
    field(:name_of_cto, :string)
    field(:gstin, :string)
    field(:corporate_id, :string)
    field(:phone, :string)
    field(:email, :string)
    field(:logo, WraftDocWeb.LogoUploader.Type)
    has_many(:users, WraftDoc.Account.User)
    has_many(:approval_systems, WraftDoc.Enterprise.ApprovalSystem)
    has_many(:pipelines, WraftDoc.Document.Pipeline)
    has_many(:vendors, WraftDoc.Enterprise.Vendor)
    timestamps()
  end

  def changeset(%Organisation{} = organisation, attrs \\ %{}) do
    organisation
    |> cast(attrs, [
      :name,
      :legal_name,
      :address,
      :name_of_ceo,
      :name_of_cto,
      :gstin,
      :corporate_id,
      :phone,
      :email
    ])
    |> validate_required([:name, :legal_name])
    |> cast_attachments(attrs, [:logo])
    |> unique_constraint(:legal_name,
      message: "Organisation name already taken.! Try another one.",
      name: :organisation_unique_index
    )
    |> unique_constraint(:gstin,
      message: "GSTIN Already Registered",
      name: :organisation_gstin_unique_index
    )
  end
end
