defmodule WraftDoc.Account.User do
  @moduledoc """
  The user model.
  """
  use WraftDoc.Schema
  @derive {Jason.Encoder, only: [:name, :email, :current_org_id]}

  schema "user" do
    field(:name, :string)
    field(:email, :string)
    field(:encrypted_password, :string)
    field(:password, :string, virtual: true)
    field(:email_verify, :boolean, default: false)
    field(:is_guest, :boolean, default: false)
    field(:deleted_at, :naive_datetime)
    field(:signed_in_at, :naive_datetime)
    field(:last_signed_in_org, Ecto.UUID)
    field(:current_org_id, Ecto.UUID, virtual: true)
    field(:role_names, {:array, :string}, virtual: true)
    field(:permissions, {:array, :string}, virtual: true)

    many_to_many(:organisations, WraftDoc.Enterprise.Organisation,
      join_through: "users_organisations"
    )

    many_to_many(:state, WraftDoc.Enterprise.Flow.State, join_through: "state_users")

    has_many(:user_organisations, WraftDoc.Account.UserOrganisation)

    has_one(:profile, WraftDoc.Account.Profile)

    has_many(:layouts, WraftDoc.Document.Layout, foreign_key: :creator_id)
    has_many(:content_types, WraftDoc.Document.ContentType, foreign_key: :creator_id)
    has_many(:themes, WraftDoc.Document.Theme, foreign_key: :creator_id)
    has_many(:flows, WraftDoc.Enterprise.Flow, foreign_key: :creator_id)
    has_many(:states, WraftDoc.Enterprise.Flow.State, foreign_key: :creator_id)
    has_many(:data_templates, WraftDoc.Document.DataTemplate, foreign_key: :creator_id)
    has_many(:assets, WraftDoc.Document.Asset, foreign_key: :creator_id)
    has_many(:template_assets, WraftDoc.TemplateAssets.TemplateAsset, foreign_key: :creator_id)
    has_many(:build_histories, WraftDoc.Document.Instance.History, foreign_key: :creator_id)
    has_many(:content_collaboration, WraftDoc.Document.ContentCollaboration)

    has_many(:blocks, WraftDoc.Document.Block, foreign_key: :creator_id)

    has_many(:field_types, WraftDoc.Document.FieldType, foreign_key: :creator_id)

    has_many(:auth_tokens, WraftDoc.AuthTokens.AuthToken, foreign_key: :user_id)

    has_many(:instance_versions, WraftDoc.Document.Instance.Version, foreign_key: :author_id)
    has_many(:user_roles, WraftDoc.Account.UserRole)
    has_many(:roles, through: [:user_roles, :role])

    has_many(:block_templates, WraftDoc.Document.BlockTemplate, foreign_key: :creator_id)
    has_many(:comments, WraftDoc.Document.Comment)
    has_many(:approval_systems, WraftDoc.Enterprise.ApprovalSystem, foreign_key: :creator_id)

    has_many(:instances_to_approve,
      through: [:approval_systems, :instance_approval_systems]
    )

    has_many(:pipelines, WraftDoc.Document.Pipeline, foreign_key: :creator_id)
    has_many(:payments, WraftDoc.Enterprise.Membership.Payment, foreign_key: :creator_id)
    has_many(:vendors, WraftDoc.Enterprise.Vendor, foreign_key: :creator_id)
    has_many(:organisation_fields, WraftDoc.Document.OrganisationField, foreign_key: :creator_id)
    has_many(:owned_organisations, WraftDoc.Enterprise.Organisation, foreign_key: :creator_id)
    has_many(:forms, WraftDoc.Forms.Form, foreign_key: :creator_id)
    has_many(:form_entry, WraftDoc.Forms.FormEntry)

    timestamps()
  end

  # TODO update email string format similar to waiting list format & corresponding tests
  def changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, [:name, :email, :password])
    |> validate_required([:name, :email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_format(:name, ~r/^[A-z ]+$/)
    |> validate_length(:name, min: 2)
    |> validate_length(:password, min: 8, max: 22)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end

  def create_changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, [:name, :email, :password, :organisation_id])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:name, min: 2)
    |> validate_length(:password, min: 8, max: 16)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end

  def update_changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2)
  end

  def update_sign_in_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:signed_in_at])
    |> validate_required([:signed_in_at])
  end

  def update_last_signed_in_org_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:last_signed_in_org])
    |> validate_required([:last_signed_in_org])
  end

  def email_status_update_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email_verify])
    |> validate_required([:email_verify])
  end

  def password_changeset(password, attrs \\ %{}) do
    password
    |> cast(attrs, [:password, :encrypted_password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 16)
    |> generate_encrypted_password
  end

  def delete_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
  end

  def guest_user_changeset(guest_user, attrs \\ %{}) do
    guest_user
    |> cast(attrs, [:email, :is_guest, :name, :password])
    |> validate_required([:email, :is_guest, :name, :password])
    |> validate_length(:name, min: 2)
    |> validate_format(:name, ~r/^[A-z ]+$/)
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end
end
