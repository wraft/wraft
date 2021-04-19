defmodule WraftDoc.Account.User do
  @moduledoc """
  The user model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:name, :email, :organisation]}
  schema "user" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string)
    field(:email, :string)
    field(:encrypted_password, :string)
    field(:password, :string, virtual: true)
    field(:email_verify, :boolean, default: false)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:role, WraftDoc.Account.Role)
    has_one(:profile, WraftDoc.Account.Profile)

    has_many(:layouts, WraftDoc.Document.Layout, foreign_key: :creator_id)
    has_many(:content_types, WraftDoc.Document.ContentType, foreign_key: :creator_id)
    has_many(:themes, WraftDoc.Document.Theme, foreign_key: :creator_id)
    has_many(:flows, WraftDoc.Enterprise.Flow, foreign_key: :creator_id)
    has_many(:states, WraftDoc.Enterprise.Flow.State, foreign_key: :creator_id)
    has_many(:data_templates, WraftDoc.Document.DataTemplate, foreign_key: :creator_id)
    has_many(:assets, WraftDoc.Document.Asset, foreign_key: :creator_id)
    has_many(:build_histories, WraftDoc.Document.Instance.History, foreign_key: :creator_id)

    has_many(:blocks, WraftDoc.Document.Block, foreign_key: :creator_id)

    has_many(:field_types, WraftDoc.Document.FieldType, foreign_key: :creator_id)
    has_many(:content_type_fields, WraftDoc.Document.FieldType, foreign_key: :creator_id)

    has_many(:auth_tokens, WraftDoc.Account.AuthToken, foreign_key: :user_id)

    has_many(:instance_versions, WraftDoc.Document.Instance.Version, foreign_key: :creator_id)
    has_many(:user_roles, WraftDoc.Account.UserRole)
    has_many(:roles, through: [:user_roles, :role])
    many_to_many(:activities, Spur.Activity, join_through: "audience")
    has_many(:block_templates, WraftDoc.Document.BlockTemplate, foreign_key: :creator_id)
    has_many(:comments, WraftDoc.Document.Comment)
    has_many(:approvers, WraftDoc.Enterprise.ApprovalSystem, foreign_key: :approver_id)
    has_many(:approval_systems, WraftDoc.Enterprise.ApprovalSystem, foreign_key: :user_id)
    has_many(:pipelines, WraftDoc.Document.Pipeline, foreign_key: :creator_id)
    has_many(:payments, WraftDoc.Enterprise.Membership.Payment, foreign_key: :creator_id)
    has_many(:vendors, WraftDoc.Enterprise.Vendor, foreign_key: :creator_id)

    timestamps()
  end

  def changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, [:name, :email, :password, :role_id, :organisation_id])
    |> validate_required([:name, :email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_format(:name, ~r/^[A-z ]+$/)
    |> validate_length(:name, min: 2)
    |> validate_length(:password, min: 8, max: 16)
    |> unique_constraint(:email, message: "Email already taken.! Try another email.")
    |> generate_encrypted_password
  end

  def create_changeset(users, attrs \\ %{}) do
    users
    |> cast(attrs, [:name, :email, :password, :role_id, :organisation_id])
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

  def password_changeset(password, attrs \\ %{}) do
    password
    |> cast(attrs, [:password, :encrypted_password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 16)
    |> generate_encrypted_password
  end

  defp generate_encrypted_password(current_changeset) do
    case current_changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(
          current_changeset,
          :encrypted_password,
          Bcrypt.hash_pwd_salt(password)
        )

      _ ->
        current_changeset
    end
  end
end
