defmodule WraftDoc.Enterprise.Organisation do
  @moduledoc """
    The organisation model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema
  alias WraftDoc.Account.{Role, User}
  alias WraftDoc.Enterprise.{Organisation, Vendor}
  alias WraftDoc.Document.{Pipeline, Theme}

  @derive {Jason.Encoder, only: [:name]}
  schema "organisation" do
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
    has_many(:users, User, where: [deleted_at: nil])
    has_many(:pipelines, Pipeline)
    has_many(:vendors, Vendor)
    has_many(:themes, Theme)

    has_many(:roles, Role)
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
    |> validate_required([:name, :legal_name, :email])
    |> cast_attachments(attrs, [:logo])
    |> unique_constraint(:legal_name,
      message: "Organisation Already Registered.",
      name: :organisation_unique_index
    )
    |> unique_constraint(:gstin,
      message: "GSTIN Already Registered",
      name: :organisation_gstin_unique_index
    )
  end
end
