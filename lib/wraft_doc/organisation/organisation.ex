defmodule WraftDoc.Enterprise.Organisation do
  @moduledoc """
    The organisation model.
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Document.Pipeline
  alias WraftDoc.Document.Theme
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Vendor

  @fields ~w(name legal_name email address name_of_ceo name_of_cto gstin corporate_id phone creator_id)a

  @derive {Jason.Encoder, only: [:name]}
  schema "organisation" do
    field(:name, :string)
    field(:legal_name, :string)
    field(:address, :string)
    field(:name_of_ceo, :string)
    field(:name_of_cto, :string)
    field(:gstin, :string)
    field(:corporate_id, :string)
    field(:phone, :string)
    field(:email, :string)
    belongs_to(:creator, User)
    field(:logo, WraftDocWeb.LogoUploader.Type)
    has_many(:users_organisations, UserOrganisation)
    has_many(:fields, WraftDoc.Document.Field)
    has_many(:forms, WraftDoc.Forms.Form)
    many_to_many(:users, User, join_through: "users_organisations")
    has_many(:pipelines, Pipeline)
    has_many(:vendors, Vendor)
    has_many(:themes, Theme)

    has_many(:roles, Role)
    timestamps()
  end

  def changeset(%Organisation{} = organisation, attrs \\ %{}) do
    organisation
    |> cast(attrs, @fields)
    |> validate_required([:name, :legal_name, :email, :creator_id])
    |> validate_name()
    |> unique_constraint(:name,
      message: "organisation name already exist",
      name: :organisation_name_creator_id_index
    )
    |> unique_constraint(:legal_name,
      message: "Organisation Already Registered.",
      name: :organisation_legal_name_unique_index
    )
    |> unique_constraint(:gstin,
      message: "GSTIN Already Registered",
      name: :organisation_gstin_unique_index
    )
  end

  def personal_organisation_changeset(%Organisation{} = organisation, attrs \\ %{}) do
    organisation
    |> cast(attrs, @fields)
    |> validate_required([:name, :email])
    |> validate_format(:name, ~r/^Personal$/)
  end

  def logo_changeset(%Organisation{} = organisation, attrs \\ %{}) do
    cast_attachments(organisation, attrs, [:logo])
  end

  defp validate_name(changeset) do
    if get_field(changeset, :name) == "Personal" do
      add_error(changeset, :name, "The name 'Personal' is not allowed.")
    else
      changeset
    end
  end
end
